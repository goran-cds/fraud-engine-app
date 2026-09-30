import Config

kafka_host =
  System.get_env("KAFKA_HOST") || "localhost"

kafka_port =
  System.get_env("KAFKA_PORT") || 9092

config :kaffe,
  producer: [
    endpoints: "#{kafka_host}:#{kafka_port}",
    topics: ["transactions.raw"]
  ]

if config_env() != :test do
  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")
end
