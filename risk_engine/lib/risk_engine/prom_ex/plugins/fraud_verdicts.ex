defmodule RiskEngine.PromEx.Plugins.FraudVerdicts do
  @moduledoc """
  Metrics for fast-path fraud verdicts.
  """
  use PromEx.Plugin

  @event [:risk_engine, :fraud, :verdict, :stop]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :risk_engine_fraud_verdicts_event_metrics,
      [
        counter(
          [:risk_engine, :fraud, :verdict, :total],
          event_name: @event,
          description: "Count of fast-path fraud verdicts by outcome",
          tags: [:path, :verdict],
          tag_values: & &1
        ),
        distribution(
          [:risk_engine, :fraud, :verdict, :duration, :milliseconds],
          event_name: @event,
          measurement: :duration,
          unit: {:native, :millisecond},
          description: "Time to reach a fast-path fraud verdict",
          tags: [:path],
          tag_values: & &1,
          reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]]
        )
      ]
    )
  end
end
