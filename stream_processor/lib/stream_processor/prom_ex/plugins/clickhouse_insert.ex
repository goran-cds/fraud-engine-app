defmodule StreamProcessor.PromEx.Plugins.ClickhouseInsert do
  @moduledoc """
  Metrics for the ClickHouse insert path.
  """
  use PromEx.Plugin

  @event [:stream_processor, :clickhouse, :insert, :stop]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :stream_processor_clickhouse_insert_event_metrics,
      [
        counter(
          [:stream_processor, :clickhouse, :insert, :total],
          event_name: @event,
          description: "Count of transaction inserts into ClickHouse"
        ),
        distribution(
          [:stream_processor, :clickhouse, :insert, :duration, :milliseconds],
          event_name: @event,
          measurement: :duration,
          unit: {:native, :millisecond},
          description: "Time to insert a scored transaction into ClickHouse",
          reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500]]
        )
      ]
    )
  end
end
