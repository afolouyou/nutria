defmodule Nutria.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Nutria.Finch},
      Nutria.Repo,
      {Task.Supervisor, name: Nutria.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Nutria.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
