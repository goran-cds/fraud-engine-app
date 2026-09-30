defmodule SharedContracts.MixProject do
  use Mix.Project

  def project do
    [
      app: :shared_contracts,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:protobuf, "~> 0.15"},
      {:grpc, "~> 0.11.5"},
      {:opentelemetry_api, "~> 1.5"}
    ]
  end
end
