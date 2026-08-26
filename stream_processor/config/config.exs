import Config

# With no Schema Registry configured, it reads schema files straight off disk.
# We tell it those files live under shared_contracts' priv/schemas directory, where the shared .avsc contract is defined.
config :avrora, otp_app: :shared_contracts

config :stream_processor, StreamProcessor.Infra.ClickhouseClient,
  host: "localhost",
  port: 8123,
  database: "default",
  username: "default",
  password: "default"
