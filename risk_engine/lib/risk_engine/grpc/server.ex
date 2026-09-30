defmodule RiskEngine.GRPC.Server do
  use GRPC.Server, service: SharedContracts.RiskEngine.Service

  alias RiskEngine.Infra.KafkaProducer
  alias RiskEngine.Validator.Verifier

  require OpenTelemetry.Tracer, as: Tracer

  def score_transaction(request, _stream) do
    decision = Verifier.validate(request)

    produce_async(request, decision)
    decision
  end

  def stream_transactions(request_stream, stream) do
    Enum.each(request_stream, fn request ->
      decision = Verifier.validate(request)

      produce_async(request, decision)
      GRPC.Server.send_reply(stream, decision)
    end)
  end

  defp produce_async(request, decision) do
    # The produce call happens on a separate process from this one
    # OTel context lives in the process dictionary, so it must be captured
    # here and re-attached inside the task or the produce span would start a new,
    # disconnected trace instead of nesting under this RPC's span.
    otel_ctx = OpenTelemetry.Ctx.get_current()

    Task.Supervisor.start_child(RiskEngine.TaskSupervisor, fn ->
      OpenTelemetry.Ctx.attach(otel_ctx)

      :telemetry.span([:risk_engine, :kafka, :produce], %{}, fn ->
        result =
          Tracer.with_span "risk_engine.kafka.produce", kind: :producer do
            headers =
              []
              |> :otel_propagator_text_map.inject()
              |> Enum.map(fn {k, v} -> {k, v} end)

            KafkaProducer.produce_transaction_scored(
              transaction_scored_payload(request, decision),
              headers
            )
          end

        {result, %{}}
      end)
    end)
  end

  defp transaction_scored_payload(request, decision) do
    %{
      "transaction_id" => request.transaction_id,
      "account_id" => request.account_id,
      "amount_cents" => request.amount_cents,
      "currency" => request.currency,
      "merchant_id" => request.merchant_id,
      "ip_address" => request.ip_address,
      "device_fingerprint" => request.device_fingerprint,
      "timestamp" => request.timestamp,
      "metadata" => request.metadata,
      "fast_path_verdict" => Atom.to_string(decision.verdict),
      "provisional" => decision.provisional
    }
  end
end
