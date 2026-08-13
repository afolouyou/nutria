defmodule Nutria.PantryTest do
  use Nutria.DataCase

  alias Nutria.Accounts
  alias Nutria.Pantry

  setup do
    {:ok, %{user: user}} =
      Accounts.register(%{
        "email" => "pantry@example.com",
        "password" => "senha123",
        "name" => "Pantry"
      })

    %{user: user}
  end

  describe "add_item/2" do
    test "accepts integer quantity strings without decimal point", %{user: user} do
      assert {:ok, item} =
               Pantry.add_item(user.id, %{"name" => "Arroz", "quantity" => "1", "unit" => "kg"})

      assert item["quantity"] == 1.0
    end

    test "accepts decimal quantity strings", %{user: user} do
      assert {:ok, item} =
               Pantry.add_item(user.id, %{"name" => "Feijão", "quantity" => "0.5", "unit" => "kg"})

      assert item["quantity"] == 0.5
    end

    test "merges duplicates by normalized name and unit", %{user: user} do
      assert {:ok, item1} =
               Pantry.add_item(user.id, %{"name" => "Arroz", "quantity" => "1", "unit" => "kg"})

      assert {:ok, item2} =
               Pantry.add_item(user.id, %{
                 "name" => "  arroz  ",
                 "quantity" => "2",
                 "unit" => "kg"
               })

      assert item1["id"] == item2["id"]
      assert item2["quantity"] == 3.0
    end

    test "keeps same name with different units separate", %{user: user} do
      assert {:ok, item1} =
               Pantry.add_item(user.id, %{"name" => "Arroz", "quantity" => "1", "unit" => "kg"})

      assert {:ok, item2} =
               Pantry.add_item(user.id, %{"name" => "Arroz", "quantity" => "500", "unit" => "g"})

      assert item1["id"] != item2["id"]
    end

    test "rejects invalid input", %{user: user} do
      assert {:error, :bad_request, _} =
               Pantry.add_item(user.id, %{"name" => "", "quantity" => "1", "unit" => "kg"})

      assert {:error, :bad_request, _} =
               Pantry.add_item(user.id, %{"name" => "X", "quantity" => "abc", "unit" => "kg"})

      assert {:error, :bad_request, _} =
               Pantry.add_item(user.id, %{"name" => "X", "quantity" => "1", "unit" => "gaveta"})
    end
  end

  describe "list_items/1" do
    test "returns only own items", %{user: user} do
      {:ok, %{user: other}} =
        Accounts.register(%{
          "email" => "outro@example.com",
          "password" => "senha123",
          "name" => "Outro"
        })

      {:ok, _} = Pantry.add_item(user.id, %{"name" => "Arroz", "quantity" => "1", "unit" => "kg"})

      {:ok, _} =
        Pantry.add_item(other.id, %{"name" => "Açúcar", "quantity" => "1", "unit" => "kg"})

      assert [%{"name" => "Arroz"}] = Pantry.list_items(user.id)
    end
  end

  describe "delete_item/2 and update_quantity/2" do
    test "delete removes only own items", %{user: user} do
      {:ok, item} =
        Pantry.add_item(user.id, %{"name" => "Sal", "quantity" => "1", "unit" => "un"})

      assert {:error, :not_found, _} =
               Pantry.delete_item(item["id"], Ecto.UUID.generate())

      assert :ok = Pantry.delete_item(item["id"], user.id)
      assert Pantry.list_items(user.id) == []
    end

    test "update_quantity deletes item when it reaches zero", %{user: user} do
      {:ok, item} =
        Pantry.add_item(user.id, %{"name" => "Sal", "quantity" => "1", "unit" => "un"})

      assert :deleted = Pantry.update_quantity(item["id"], 0)
      assert Pantry.list_items(user.id) == []
    end
  end
end
