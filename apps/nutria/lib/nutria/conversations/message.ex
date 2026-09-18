defmodule Nutria.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field(:role, :string)
    field(:text, :string)
    field(:card, :map)
    belongs_to(:conversation, Nutria.Conversations.Conversation)

    timestamps(updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :text, :conversation_id, :card])
    |> validate_required([:role, :text, :conversation_id])
    |> validate_inclusion(:role, ["user", "assistant"])
  end
end
