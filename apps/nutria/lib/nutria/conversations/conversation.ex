defmodule Nutria.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :title, :string
    belongs_to :user, Nutria.Accounts.User
    has_many :messages, Nutria.Conversations.Message

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :user_id])
    |> validate_required([:title, :user_id])
  end
end
