defmodule RiskEngine.PromEx do
  use PromEx, otp_app: :risk_engine

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      RiskEngine.PromEx.Plugins.FraudVerdicts,
      RiskEngine.PromEx.Plugins.KafkaProduce
    ]
  end

  @impl true
  def dashboard_assigns, do: [datasource_id: "prometheus"]
end
