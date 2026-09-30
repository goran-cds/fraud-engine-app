defmodule ClientSimulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :client_simulator,
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
      mod: {ClientSimulator.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:grpc, "~> 0.11.5"},
      {:shared_contracts, path: "../shared_contracts"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.11"},
      {:opentelemetry_semantic_conventions, "~> 1.27"}
    ]
  end
end
