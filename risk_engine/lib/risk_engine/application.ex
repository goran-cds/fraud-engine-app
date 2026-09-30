defmodule RiskEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Must be first to capture init telemetry emitted by the children below.
      RiskEngine.PromEx,
      {GRPC.Server.Supervisor,
       endpoint: RiskEngine.GRPC.Endpoint, port: 50051, start_server: true},
      {Task.Supervisor, name: RiskEngine.TaskSupervisor},
      Avrora,
      RiskEngine.Cache.Blocklist,
      RiskEngine.Cache.SeenAccounts,
      RiskEngine.Cache.Velocity
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RiskEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
