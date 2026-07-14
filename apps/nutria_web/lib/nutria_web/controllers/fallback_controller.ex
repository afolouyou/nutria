defmodule NutriaWeb.Controllers.FallbackController do
  @moduledoc """
  Fallback controller for rendering errors as JSON matching the Python backend format.
  """
  use NutriaWeb, :controller

  def call(conn, {:error, :unauthorized, detail}) do
    conn |> put_status(401) |> json(%{"detail" => detail})
  end

  def call(conn, {:error, :not_found, detail}) do
    conn |> put_status(404) |> json(%{"detail" => detail})
  end

  def call(conn, {:error, :bad_request, detail}) do
    conn |> put_status(400) |> json(%{"detail" => detail})
  end

  def call(conn, {:error, :bad_gateway, detail}) do
    conn |> put_status(502) |> json(%{"detail" => detail})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    message =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
      |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
      |> Enum.join("; ")

    conn |> put_status(400) |> json(%{"detail" => message})
  end

  def call(conn, _) do
    conn |> put_status(500) |> json(%{"detail" => "Erro interno"})
  end
end
