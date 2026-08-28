defmodule RiskEngine.GRPC.Server do
  use GRPC.Server, service: SharedContracts.RiskEngine.Service

  alias RiskEngine.Infra.KafkaProducer
  alias RiskEngine.Validator.Verifier

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
    Task.Supervisor.start_child(RiskEngine.TaskSupervisor, fn ->
      KafkaProducer.produce_transaction_scored(transaction_scored_payload(request, decision))
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
