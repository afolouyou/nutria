defmodule Nutria.MixProject do
  use Mix.Project

  def project do
    [
      app: :nutria,
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
      extra_applications: [:logger],
      mod: {Nutria.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:joken, "~> 2.6"},
      {:bcrypt_elixir, "~> 3.0"},
      {:gemini_ex, "~> 0.14.0"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"}
    ]
  end
end
