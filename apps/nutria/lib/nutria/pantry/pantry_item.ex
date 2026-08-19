defmodule Nutria.Pantry.PantryItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_units ~w(g kg ml l un)
  @valid_categories ~w(Mantimentos Refrigerados Hortifruti Temperos Outros)
  @low_stock_thresholds %{"g" => 200, "kg" => 0.2, "ml" => 200, "l" => 0.2, "un" => 2}

  schema "pantry_items" do
    field(:name, :string)
    field(:name_norm, :string)
    field(:quantity, :float)
    field(:unit, :string)
    field(:category, :string, default: "Outros")
    belongs_to(:user, Nutria.Accounts.User)

    timestamps(updated_at: false)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :quantity, :unit, :category, :user_id])
    |> validate_required([:name, :quantity, :unit, :user_id])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_inclusion(:unit, @valid_units)
    |> validate_inclusion(:category, @valid_categories)
    |> normalize_name()
  end

  def low_stock?(quantity, unit) do
    threshold = Map.get(@low_stock_thresholds, String.downcase(unit), 1)
    quantity <= threshold
  end

  def valid_unit?(unit), do: unit in @valid_units
  def valid_category?(category), do: category in @valid_categories

  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        changeset
        |> put_change(:name, String.trim(name))
        |> put_change(:name_norm, name |> String.trim() |> String.downcase())
    end
  end
end
