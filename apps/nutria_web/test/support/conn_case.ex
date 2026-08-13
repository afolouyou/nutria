defmodule NutriaWeb.ConnCase do
  @moduledoc """
  Test case with Postgres sandbox and connection helpers for the `nutria_web` app.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import NutriaWeb.ConnCase

      alias Nutria.Repo

      @endpoint NutriaWeb.Endpoint
    end
  end

  setup tags do
    Ecto.Adapters.SQL.Sandbox.checkout(Nutria.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Nutria.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
