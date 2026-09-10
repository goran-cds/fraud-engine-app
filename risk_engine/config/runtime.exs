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
