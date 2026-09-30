defmodule StreamProcessor.PromEx do
  use PromEx, otp_app: :stream_processor

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      Plugins.Broadway,
      StreamProcessor.PromEx.Plugins.FraudVerdicts,
      StreamProcessor.PromEx.Plugins.ClickhouseInsert
    ]
  end

  @impl true
  def dashboard_assigns, do: [datasource_id: "prometheus"]
end
