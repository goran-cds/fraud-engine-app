import Config

config :opentelemetry,
  resource: [service: %{name: "client_simulator", namespace: "fraud-engine"}]

config :opentelemetry, :processors,
  otel_batch_processor: %{exporter: {:opentelemetry_exporter, %{}}, scheduled_delay_ms: 100}
