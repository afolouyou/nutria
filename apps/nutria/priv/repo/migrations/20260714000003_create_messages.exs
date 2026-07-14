defmodule Nutria.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false
      add :text, :text, null: false
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false

      add :inserted_at, :naive_datetime, null: false
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:conversation_id, :inserted_at])
  end
end
