import Config

kafka_host =
  System.get_env("KAFKA_HOST") || "localhost"

kafka_port =
  System.get_env("KAFKA_PORT") || 9092

clickhouse_host =
  System.get_env("CLICKHOUSE_HOST") || "localhost"

clickhouse_port =
  case System.get_env("CLICKHOUSE_PORT") do
    nil -> 8123
    port -> String.to_integer(port)
  end

clickhouse_db =
  System.get_env("CLICKHOUSE_DB") || "default"

clickhouse_user =
  System.get_env("CLICKHOUSE_USER") || "default"

clickhouse_password =
  System.get_env("CLICKHOUSE_PASSWORD") || "default"

config :stream_processor, StreamProcessor.Infra.ClickhouseClient,
  host: clickhouse_host,
  port: clickhouse_port,
  database: clickhouse_db,
  username: clickhouse_user,
  password: clickhouse_password

config :stream_processor, StreamProcessor.Infra.KafkaConsumer,
  kafka_host: kafka_host,
  kafka_port: kafka_port
