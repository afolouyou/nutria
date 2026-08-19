defmodule NutriaWeb.Controllers.PantryController do
  use NutriaWeb, :controller

  action_fallback(NutriaWeb.Controllers.FallbackController)

  def index(conn, _params) do
    user_id = conn.assigns.current_user_id
    items = Nutria.Pantry.list_items(user_id)
    json(conn, items)
  end

  def create(conn, params) do
    user_id = conn.assigns.current_user_id
    attrs = %{
      "name" => params["name"],
      "quantity" => params["quantity"],
      "unit" => params["unit"]
    }

    attrs =
      case params["category"] do
        category when is_binary(category) and category != "" -> Map.put(attrs, "category", category)
        _ -> attrs
      end

    case Nutria.Pantry.add_item(user_id, attrs) do
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
