defmodule RiskEngine.Otel.GrpcServerInterceptor do
  @moduledoc """
  Extracts an incoming trace context from gRPC request headers and wraps the RPC in a server span.
  """
  @behaviour GRPC.Server.Interceptor

  require OpenTelemetry.Tracer, as: Tracer

  @impl true
  def init(opts), do: opts

  @impl true
  def call(request, stream, next, _opts) do
    extract_context(stream)

    Tracer.with_span "#{stream.service_name}/#{stream.method_name}", kind: :server do
      Tracer.set_attributes(%{
        "rpc.system" => "grpc",
        "rpc.service" => stream.service_name,
        "rpc.method" => stream.method_name
      })

      next.(request, stream)
    end
  end

  defp extract_context(%{adapter: adapter, payload: payload}) do
    payload
    |> adapter.get_headers()
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> :otel_propagator_text_map.extract()
  end
end
