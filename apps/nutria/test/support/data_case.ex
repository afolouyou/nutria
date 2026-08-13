defmodule Nutria.DataCase do
  @moduledoc """
  Test case with Postgres sandbox for the `nutria` app.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Nutria.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Nutria.DataCase
    end
  end

  setup tags do
    Ecto.Adapters.SQL.Sandbox.checkout(Nutria.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Nutria.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  Returns a map of field => errors for the given changeset.
  """
  def errors_on(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
