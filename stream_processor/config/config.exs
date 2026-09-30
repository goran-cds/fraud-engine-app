import Config

# With no Schema Registry configured, it reads schema files straight off disk.
# We tell it those files live under shared_contracts' priv/schemas directory, where the shared .avsc contract is defined.
config :avrora, otp_app: :shared_contracts

config :opentelemetry,
  resource: [service: %{name: "stream_processor", namespace: "fraud-engine"}]

config :opentelemetry, :processors,
  otel_batch_processor: %{exporter: {:opentelemetry_exporter, %{}}}

config :stream_processor, StreamProcessor.PromEx,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  metrics_server: [
    port: 9569,
    path: "/metrics",
    protocol: :http,
    pool_size: 5,
    cowboy_opts: []
  ]
