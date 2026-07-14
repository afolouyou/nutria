defmodule NutriaWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Nutria.PubSub},
      NutriaWeb.Telemetry,
      NutriaWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: NutriaWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NutriaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
