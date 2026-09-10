defmodule StreamProcessor.Infra.KafkaConsumer do
  use Broadway

  require Logger

  @topic "transactions.raw"
  @schema_name "com.fraud_engine.Transaction"

  def start_link(_opts) do
    config = config()

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayKafka.Producer,
           [
             hosts: "#{config.host}:#{config.port}",
             topics: [@topic],
             group_id: "stream-processor-transaction-consumer"
           ]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 10]
      ]
    )
  end

  @impl true
  def handle_message(_processor, message, _context) do
    case decode_avro(message.data) do
      {:ok, decoded} ->
        Logger.info("consumed transaction: #{inspect(decoded)}")
        StreamProcessor.persist_transaction(decoded)
        Broadway.Message.update_data(message, fn _ -> decoded end)

      {:error, reason} ->
        Logger.error("failed to decode message from #{@topic}: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  @impl true
  def handle_failed(messages, _context) do
    Enum.each(messages, fn message ->
      Logger.error("failed to process message: #{inspect(message.data)}")
    end)

    messages
  end

  defp decode_avro(avro_binary) do
    case Avrora.decode(avro_binary, schema_name: @schema_name) do
      {:ok, [decoded]} -> {:ok, decoded}
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp config() do
    config = Application.get_env(:stream_processor, __MODULE__)

    %{
      host: Keyword.fetch!(config, :kafka_host),
      port: Keyword.fetch!(config, :kafka_port)
    }
  end
end
