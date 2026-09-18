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

  def update(conn, %{"id" => id} = params) do
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

    case Nutria.Pantry.update_item(user_id, id, attrs) do
      {:ok, item} -> json(conn, item)
      {:error, _, _} = error -> error
    end
  end

  def recipes(conn, params) do
    user_id = conn.assigns.current_user_id
    notes = params["notes"]
    conversation_id = params["conversation_id"]

    case Nutria.Recipes.generate_from_pantry(user_id, notes) do
      {:ok, response} ->
        case persist_recipe(user_id, response, conversation_id) do
          {:ok, payload} -> json(conn, payload)
          {:error, _, _} = error -> error
        end

      {:error, _, _} = error ->
        error
    end
  end

  defp persist_recipe(user_id, response, conversation_id) do
    text = to_string(response["suggestions"] || "")
    recipe = response["recipe"]

    title =
      case recipe do
        %{"name" => name} when is_binary(name) and name != "" ->
          if String.length(name) > 50 do
            String.slice(name, 0, 50) <> "..."
          else
            name
          end

        _ ->
          "Receita da despensa"
      end

    with {:ok, conv_id} <- resolve_conversation(user_id, conversation_id, title),
         {:ok, msg} <- Nutria.Conversations.add_message(conv_id, "assistant", text, recipe) do
      data = %{
        "id" => msg.id,
        "role" => "assistant",
        "text" => msg.text,
        "card" => msg.card,
        "created_at" => DateTime.from_naive!(msg.inserted_at, "Etc/UTC") |> DateTime.to_iso8601()
      }

      {:ok, Map.merge(response, %{"conversation_id" => conv_id, "assistant_message" => data})}
    end
  end

  defp resolve_conversation(user_id, conversation_id, _title)
       when is_binary(conversation_id) and conversation_id != "" do
    case Nutria.Repo.get(Nutria.Conversations.Conversation, conversation_id) do
      %{user_id: ^user_id} -> {:ok, conversation_id}
      _ -> {:error, :not_found, "Conversa não encontrada"}
    end
  end

  defp resolve_conversation(user_id, _conversation_id, title) do
    case Nutria.Conversations.create_conversation(user_id, title) do
      {:ok, conv} -> {:ok, conv.id}
      error -> error
    end
  end
end
