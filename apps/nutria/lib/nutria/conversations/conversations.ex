defmodule Nutria.Conversations do
  @moduledoc """
  Conversations context — CRUD for conversations and messages.
  """
  import Ecto.Query

  alias Nutria.Repo
  alias Nutria.Conversations.{Conversation, Message}

  def list_conversations(user_id) do
    Conversation
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.updated_at)
    |> limit(200)
    |> Repo.all()
    |> Enum.map(&conversation_to_map/1)
  end

  def get_conversation(conv_id, user_id) do
    case Repo.get_by(Conversation, id: conv_id, user_id: user_id) do
      nil ->
        {:error, :not_found, "Conversa não encontrada"}

      conv ->
        messages =
          Message
          |> where([m], m.conversation_id == ^conv_id)
          |> order_by([m], asc: m.inserted_at)
          |> limit(1000)
          |> Repo.all()
          |> Enum.map(&message_to_map/1)

        {:ok,
         %{
           "id" => conv.id,
           "title" => conv.title,
           "created_at" =>
             DateTime.from_naive!(conv.inserted_at, "Etc/UTC") |> DateTime.to_iso8601(),
           "updated_at" =>
             DateTime.from_naive!(conv.updated_at, "Etc/UTC") |> DateTime.to_iso8601(),
           "messages" => messages
         }}
    end
  end

  def create_conversation(user_id, title) do
    %Conversation{}
    |> Conversation.changeset(%{title: title, user_id: user_id})
    |> Repo.insert()
    |> case do
      {:ok, conv} -> {:ok, conv}
      error -> error
    end
  end

  def delete_conversation(conv_id, user_id) do
    case Repo.get_by(Conversation, id: conv_id, user_id: user_id) do
      nil ->
        {:error, :not_found, "Conversa não encontrada"}

      conv ->
        Message |> where([m], m.conversation_id == ^conv_id) |> Repo.delete_all()
        Repo.delete(conv)
        :ok
    end
  end

  def update_conversation_timestamp(conv_id) do
    conv = Repo.get!(Conversation, conv_id)
    conv |> Conversation.changeset(%{}) |> Repo.update!()
  end

  def add_message(conversation_id, role, text) do
    %Message{}
    |> Message.changeset(%{conversation_id: conversation_id, role: role, text: text})
    |> Repo.insert()
  end

  def get_prior_messages(conversation_id, exclude_message_id \\ nil) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> maybe_exclude(exclude_message_id)
    |> order_by([m], asc: m.inserted_at)
    |> limit(1000)
    |> Repo.all()
  end

  defp maybe_exclude(query, nil), do: query
  defp maybe_exclude(query, exclude_id), do: where(query, [m], m.id != ^exclude_id)

  defp conversation_to_map(%Conversation{} = conv) do
    %{
      "id" => conv.id,
      "title" => conv.title,
      "created_at" => DateTime.from_naive!(conv.inserted_at, "Etc/UTC") |> DateTime.to_iso8601(),
      "updated_at" => DateTime.from_naive!(conv.updated_at, "Etc/UTC") |> DateTime.to_iso8601()
    }
  end

  defp message_to_map(%Message{} = msg) do
    %{
      "id" => msg.id,
      "role" => msg.role,
      "text" => msg.text,
      "created_at" => DateTime.from_naive!(msg.inserted_at, "Etc/UTC") |> DateTime.to_iso8601()
    }
  end
end
