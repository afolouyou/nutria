defmodule NutriaWeb.Controllers.PantryController do
  use NutriaWeb, :controller

  action_fallback(NutriaWeb.Controllers.FallbackController)

  def index(conn, _params) do
    user_id = conn.assigns.current_user_id
    items = Nutria.Pantry.list_items(user_id)
    json(conn, items)
  end

  def create(conn, %{"name" => name, "quantity" => quantity, "unit" => unit}) do
    user_id = conn.assigns.current_user_id

    case Nutria.Pantry.add_item(user_id, %{"name" => name, "quantity" => quantity, "unit" => unit}) do
      {:ok, item} -> json(conn, item)
      {:error, _, _} = error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id

    case Nutria.Pantry.delete_item(id, user_id) do
      :ok -> json(conn, %{"ok" => true})
      {:error, _, _} = error -> error
    end
  end

  def recipes(conn, params) do
    user_id = conn.assigns.current_user_id
    notes = params["notes"]

    case Nutria.Recipes.generate_from_pantry(user_id, notes) do
      {:ok, response} -> json(conn, response)
      {:error, _, _} = error -> error
    end
  end
end
