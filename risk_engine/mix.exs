defmodule RiskEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :risk_engine,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {RiskEngine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, "~> 0.11.5"},
      {:kaffe, "~> 1.0"},
      {:avrora, "~> 0.30"},
      {:shared_contracts, path: "../shared_contracts"}
    ]
  end
end
