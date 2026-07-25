defmodule NutriaWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :nutria_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {NutriaWeb.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons, "~> 0.5"},
      {:cors_plug, "~> 3.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:nutria, in_umbrella: true}
    ]
  end
end
