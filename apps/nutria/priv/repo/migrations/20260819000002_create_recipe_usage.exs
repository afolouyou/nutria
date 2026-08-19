defmodule Nutria.Repo.Migrations.CreateRecipeUsage do
  use Ecto.Migration

  def change do
    create table(:recipe_usage, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:used_at, :naive_datetime, null: false)

      timestamps(updated_at: false)
    end

    create(index(:recipe_usage, [:user_id]))
    create(index(:recipe_usage, [:user_id, :used_at]))
  end
end
