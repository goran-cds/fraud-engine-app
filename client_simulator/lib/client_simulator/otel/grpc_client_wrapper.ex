defmodule ClientSimulator.Otel.GrpcClientWrapper do
  @moduledoc """
  Wraps calls to `ClientSimulator.Infra.RiskEngineClient` in a client span and
  injects the trace context into outgoing gRPC metadata, so `risk_engine`'s
  server interceptor has something to extract.
  """
  alias ClientSimulator.Infra.RiskEngineClient
  alias SharedContracts.TransactionRequest

  require OpenTelemetry.Tracer, as: Tracer

  @spec score_transaction(%TransactionRequest{}, String.t()) :: {:ok, any()} | {:error, any()}
  def score_transaction(transaction, address) do
    Tracer.with_span "client_simulator.grpc.request", kind: :client do
      Tracer.set_attributes(%{
        "rpc.system" => "grpc",
        "rpc.service" => "shared_contracts.RiskEngine",
        "rpc.method" => "ScoreTransaction"
      })

      metadata =
        []
        |> :otel_propagator_text_map.inject()
        |> Map.new()

      RiskEngineClient.score_transaction(transaction, address, metadata: metadata)
    end
  end
end
