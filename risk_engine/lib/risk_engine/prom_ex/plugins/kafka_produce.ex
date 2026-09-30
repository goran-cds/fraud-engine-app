defmodule RiskEngine.PromEx.Plugins.KafkaProduce do
  @moduledoc """
  Metrics for producing scored transactions to `transactions.raw`.
  """
  use PromEx.Plugin

  @event [:risk_engine, :kafka, :produce, :stop]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :risk_engine_kafka_produce_event_metrics,
      [
        counter(
          [:risk_engine, :kafka, :produce, :total],
          event_name: @event,
          description: "Count of produce attempts to transactions.raw"
        ),
        distribution(
          [:risk_engine, :kafka, :produce, :duration, :milliseconds],
          event_name: @event,
          measurement: :duration,
          unit: {:native, :millisecond},
          description: "Time to produce a scored transaction to Kafka",
          reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500]]
        )
      ]
    )
  end
end
