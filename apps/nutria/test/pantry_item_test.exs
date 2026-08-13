defmodule Nutria.Pantry.PantryItemTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias Nutria.Pantry.PantryItem

  describe "changeset/2" do
    test "is valid with valid attributes" do
      changeset =
        PantryItem.changeset(%PantryItem{}, %{
          name: "Arroz",
          quantity: 1.5,
          unit: "kg",
          user_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
      assert get_field(changeset, :name_norm) == "arroz"
    end

    test "normalizes and trims the name" do
      changeset =
        PantryItem.changeset(%PantryItem{}, %{
          name: "  Arroz  ",
          quantity: 1,
          unit: "kg",
          user_id: Ecto.UUID.generate()
        })

      assert get_field(changeset, :name) == "Arroz"
      assert get_field(changeset, :name_norm) == "arroz"
    end

    test "rejects invalid unit" do
      changeset =
        PantryItem.changeset(%PantryItem{}, %{
          name: "Arroz",
          quantity: 1,
          unit: "gaveta",
          user_id: Ecto.UUID.generate()
        })

      refute changeset.valid?
      assert errors_on(changeset)[:unit]
    end

    test "rejects non-positive quantity" do
      changeset =
        PantryItem.changeset(%PantryItem{}, %{
          name: "Arroz",
          quantity: 0,
          unit: "kg",
          user_id: Ecto.UUID.generate()
        })

      refute changeset.valid?
      assert errors_on(changeset)[:quantity]
    end

    test "casts integer quantity strings to float" do
      changeset =
        PantryItem.changeset(%PantryItem{}, %{
          name: "Arroz",
          quantity: "1",
          unit: "kg",
          user_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
      assert get_field(changeset, :quantity) == 1.0
    end
  end

  describe "low_stock?/2" do
    test "flags quantities at or below the threshold" do
      assert PantryItem.low_stock?(0.2, "kg")
      assert PantryItem.low_stock?(200, "g")
      assert PantryItem.low_stock?(1, "un")
    end

    test "does not flag healthy stock" do
      refute PantryItem.low_stock?(5, "kg")
      refute PantryItem.low_stock?(1000, "g")
    end
  end

  describe "valid_unit?/1" do
    test "accepts only whitelisted units" do
      assert PantryItem.valid_unit?("g")
      assert PantryItem.valid_unit?("kg")
      assert PantryItem.valid_unit?("ml")
      assert PantryItem.valid_unit?("l")
      assert PantryItem.valid_unit?("un")
      refute PantryItem.valid_unit?("x")
    end
  end

  defp errors_on(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
