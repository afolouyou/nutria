defmodule Nutria.Chat do
  @moduledoc """
  Chat context — orchestrates message sending, history, and LLM.
  """
  alias Nutria.Conversations

  def send_message(user_id, text, conversation_id \\ nil, mode \\ :fast) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      {:error, :bad_request, "Mensagem vazia"}
    else
      with {:ok, conv_id} <- get_or_create_conversation(user_id, conversation_id, text) do
        {:ok, user_msg} = Conversations.add_message(conv_id, "user", text)
        prior = Conversations.get_prior_messages(conv_id, user_msg.id)

        case Nutria.LLM.chat(text, prior, mode) do
          {:ok, assistant_text} ->
            {:ok, assistant_msg} = Conversations.add_message(conv_id, "assistant", assistant_text)
            Conversations.update_conversation_timestamp(conv_id)

            {:ok,
             %{
               "conversation_id" => conv_id,
               "user_message" => format_message(user_msg),
               "assistant_message" => format_message(assistant_msg)
             }}

          {:error, _, detail} ->
            {:error, :bad_gateway, detail}
        end
      end
    end
  end

  defp get_or_create_conversation(user_id, conv_id, _text)
       when is_binary(conv_id) and conv_id != "" do
    case Nutria.Repo.get(Nutria.Conversations.Conversation, conv_id) do
      nil ->
        {:error, :not_found, "Conversa não encontrada"}

      conv ->
        if conv.user_id == user_id,
          do: {:ok, conv_id},
          else: {:error, :not_found, "Conversa não encontrada"}
    end
  end

  defp get_or_create_conversation(user_id, _conv_id, text) do
    title =
      if String.length(text) > 50,
        do: String.slice(text, 0, 50) <> "...",
        else: text

    case Conversations.create_conversation(user_id, title) do
      {:ok, conv} -> {:ok, conv.id}
      error -> error
    end
  end

  defp format_message(msg) do
    %{
      "id" => msg.id,
      "role" => msg.role,
      "text" => msg.text,
      "created_at" => DateTime.from_naive!(msg.inserted_at, "Etc/UTC") |> DateTime.to_iso8601()
    }
  end
end
