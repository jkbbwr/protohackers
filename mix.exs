defmodule Protos.MixProject do
  use Mix.Project

  def project do
    [
      app: :protos,
      version: "0.1.0",
      elixir: "~> 1.14-rc",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :lettuce],
      mod: {Protos.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:thousand_island, "~> 0.5.11"},
      {:telemetry, "~> 1.1.0"},
      {:jason, "~> 1.4.0"},
      {:prime, "~> 0.1.1"},
      {:ets, "~> 0.9.0"},
      {:lettuce, "~> 0.2.0", only: :dev}
    ]
  end
end
