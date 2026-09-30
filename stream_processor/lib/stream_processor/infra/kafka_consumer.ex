defmodule StreamProcessor.Infra.KafkaConsumer do
  use Broadway

  require Logger
  require OpenTelemetry.Tracer, as: Tracer

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

        Tracer.with_span "stream_processor.kafka.consume",
          kind: :consumer,
          links: consume_links(message) do
          StreamProcessor.persist_transaction(decoded)
        end

        Broadway.Message.update_data(message, fn _ -> decoded end)

      {:error, reason} ->
        Logger.error("failed to decode message from #{@topic}: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  # A link back to the producer's trace
  # Kafka consumption is async/batched, so a hard parent/child relationship would misrepresent it
  # (per OTel messaging semantic conventions)
  defp consume_links(%Broadway.Message{metadata: %{headers: headers}}) when is_list(headers) do
    case link_from_headers(headers) do
      nil -> []
      link -> [link]
    end
  end

  defp consume_links(_message), do: []

  defp link_from_headers(headers) do
    carrier = Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)

    :otel_ctx.new()
    |> :otel_propagator_text_map.extract_to(carrier)
    |> Tracer.current_span_ctx()
    |> OpenTelemetry.link()
  rescue
    _ -> nil
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
