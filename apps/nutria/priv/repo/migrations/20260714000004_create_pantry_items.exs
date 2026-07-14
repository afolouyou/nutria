defmodule Nutria.Repo.Migrations.CreatePantryItems do
  use Ecto.Migration

  def change do
    create table(:pantry_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :name_norm, :string, null: false
      add :quantity, :float, null: false
      add :unit, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :inserted_at, :naive_datetime, null: false
    end

    create index(:pantry_items, [:user_id])
    create unique_index(:pantry_items, [:user_id, :name_norm, :unit])
  end
end
