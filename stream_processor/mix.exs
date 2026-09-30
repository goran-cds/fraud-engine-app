defmodule StreamProcessor.MixProject do
  use Mix.Project

  def project do
    [
      app: :stream_processor,
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
      mod: {StreamProcessor.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:broadway_kafka, "~> 0.4.4"},
      {:ch, "~> 0.6.0"},
      {:avrora, "~> 0.30"},
      {:shared_contracts, path: "../shared_contracts"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.11"},
      {:opentelemetry_semantic_conventions, "~> 1.27"},
      {:prom_ex, "~> 1.12"},
      {:plug_cowboy, "~> 2.7"}
    ]
  end
end
