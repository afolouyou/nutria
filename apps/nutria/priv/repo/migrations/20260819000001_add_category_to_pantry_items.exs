defmodule Nutria.Repo.Migrations.AddCategoryToPantryItems do
  use Ecto.Migration

  def change do
    alter table(:pantry_items, primary_key: false) do
      add(:category, :string, null: false, default: "Outros")
    end

    drop_if_exists(
      unique_index(:pantry_items, [:user_id, :name_norm, :unit],
        name: :index_pantry_items_user_id_name_norm_unit_unique
      )
    )

    create(
      unique_index(:pantry_items, [:user_id, :name_norm, :unit, :category],
        name: :index_pantry_items_user_id_name_norm_unit_category_unique
      )
    )
  end
end
