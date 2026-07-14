defmodule NutriaWeb.Controllers.ConversationController do
  use NutriaWeb, :controller

  action_fallback NutriaWeb.Controllers.FallbackController

  def index(conn, _params) do
    user_id = conn.assigns.current_user_id
    conversations = Nutria.Conversations.list_conversations(user_id)
    json(conn, conversations)
  end

  def show(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id

    case Nutria.Conversations.get_conversation(id, user_id) do
      {:ok, conversation} -> json(conn, conversation)
      {:error, _, _} = error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id

    case Nutria.Conversations.delete_conversation(id, user_id) do
      :ok -> json(conn, %{"ok" => true})
      {:error, _, _} = error -> error
    end
  end
end
