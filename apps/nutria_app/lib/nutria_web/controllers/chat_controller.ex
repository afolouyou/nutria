defmodule NutriaWeb.Controllers.ChatController do
  use NutriaWeb, :controller

  action_fallback(NutriaWeb.Controllers.FallbackController)

  def create(conn, %{"text" => text} = params) do
    user_id = conn.assigns.current_user_id
    conversation_id = params["conversation_id"]

    case Nutria.Chat.send_message(user_id, text, conversation_id) do
      {:ok, response} -> json(conn, response)
      {:error, _, _} = error -> error
    end
  end
end
