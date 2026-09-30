defmodule StreamProcessor.PromEx.Plugins.FraudVerdicts do
  @moduledoc """
  Metrics for heavy-path fraud verdicts.
  """
  use PromEx.Plugin

  @event [:stream_processor, :fraud, :verdict, :stop]

  @impl true
  def event_metrics(_opts) do
    Event.build(
      :stream_processor_fraud_verdicts_event_metrics,
      [
        counter(
          [:stream_processor, :fraud, :verdict, :total],
          event_name: @event,
          description: "Count of heavy-path fraud verdicts by outcome",
          tags: [:path, :verdict],
          tag_values: & &1
        ),
        distribution(
          [:stream_processor, :fraud, :verdict, :duration, :milliseconds],
          event_name: @event,
          measurement: :duration,
          unit: {:native, :millisecond},
          description: "Time to reach a heavy-path fraud verdict",
          tags: [:path],
          tag_values: & &1,
          reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]]
        )
      ]
    )
  end
end
