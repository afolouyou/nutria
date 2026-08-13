defmodule Nutria.ConversationsTest do
  use Nutria.DataCase

  alias Nutria.Accounts
  alias Nutria.Conversations

  setup do
    {:ok, %{user: user}} =
      Accounts.register(%{
        "email" => "conv@example.com",
        "password" => "senha123",
        "name" => "Conv"
      })

    %{user: user}
  end

  describe "conversations" do
    test "create/list/get", %{user: user} do
      {:ok, conv} = Conversations.create_conversation(user.id, "Primeira conversa")
      assert conv.user_id == user.id

      assert [%{"title" => "Primeira conversa"}] = Conversations.list_conversations(user.id)

      assert {:ok, fetched} = Conversations.get_conversation(conv.id, user.id)
      assert fetched["messages"] == []
    end

    test "add_message and prior messages", %{user: user} do
      {:ok, conv} = Conversations.create_conversation(user.id, "T")
      {:ok, _} = Conversations.add_message(conv.id, "user", "Olá")
      {:ok, _} = Conversations.add_message(conv.id, "assistant", "Oi")

      assert Enum.map(Conversations.get_prior_messages(conv.id), & &1.role) == [
               "user",
               "assistant"
             ]
    end

    test "delete_conversation removes messages", %{user: user} do
      {:ok, conv} = Conversations.create_conversation(user.id, "T")
      {:ok, _} = Conversations.add_message(conv.id, "user", "Olá")

      assert :ok = Conversations.delete_conversation(conv.id, user.id)
      assert Conversations.list_conversations(user.id) == []
    end

    test "only the owner can access or delete", %{user: user} do
      {:ok, %{user: other}} =
        Accounts.register(%{
          "email" => "outro2@example.com",
          "password" => "senha123",
          "name" => "Outro"
        })

      {:ok, conv} = Conversations.create_conversation(user.id, "T")

      assert {:error, :not_found, _} = Conversations.get_conversation(conv.id, other.id)
      assert {:error, :not_found, _} = Conversations.delete_conversation(conv.id, other.id)
      assert {:ok, _} = Conversations.get_conversation(conv.id, user.id)
    end
  end
end
