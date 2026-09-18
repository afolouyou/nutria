defmodule Nutria.RecipesTest do
  use Nutria.DataCase

  alias Nutria.Accounts
  alias Nutria.Pantry
  alias Nutria.Recipes
  alias Nutria.Recipes.RecipeUsage

  setup do
    {:ok, %{user: user}} =
      Accounts.register(%{
        "email" => "recipes#{System.unique_integer([:positive])}@example.com",
        "password" => "senha123",
        "name" => "Recipes"
      })

    %{user: user}
  end

  defp add(user_id, name, qty, unit) do
    {:ok, _} = Pantry.add_item(user_id, %{"name" => name, "quantity" => qty, "unit" => unit})
  end

  defp pantry(user_id), do: Pantry.get_all_items_for_user(user_id)

  describe "deduct/2" do
    test "strips the USAGE block from the text", %{user: user} do
      add(user.id, "Arroz", "1", "kg")
      raw = "Bolo\n\n<USAGE>[{\"name\":\"Arroz\",\"quantity\":1,\"unit\":\"kg\"}]</USAGE>"

      {cleaned, _consumed, _low} = Recipes.deduct(raw, pantry(user.id))
      refute cleaned =~ "USAGE"
      assert cleaned =~ "Bolo"
    end

    test "does not crash on malformed or missing quantity", %{user: user} do
      add(user.id, "Arroz", "1", "kg")

      for bad <- ["abc", "0,", ""] do
        raw = "<USAGE>[{\"name\":\"Arroz\",\"quantity\":#{Jason.encode!(bad)}}]</USAGE>"
        assert {_cleaned, [], []} = Recipes.deduct(raw, pantry(user.id))
      end
    end

    test "converts compatible units (kg -> g)", %{user: user} do
      add(user.id, "Arroz", "1000", "g")

      raw = "<USAGE>[{\"name\":\"Arroz\",\"quantity\":0.5,\"unit\":\"kg\"}]</USAGE>"

      {_cleaned, consumed, _low} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"name" => "Arroz", "quantity" => 500.0, "unit" => "g"}] = consumed
      assert [%{"name" => "Arroz", "quantity" => 500.0, "unit" => "g"}] = Pantry.list_items(user.id)
    end

    test "accepts comma as decimal separator", %{user: user} do
      add(user.id, "Farinha", "1", "kg")

      raw = "<USAGE>[{\"name\":\"Farinha\",\"quantity\":\"0,5\",\"unit\":\"kg\"}]</USAGE>"

      {_cleaned, consumed, _low} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"name" => "Farinha", "quantity" => 0.5, "unit" => "kg"}] = consumed
      assert [%{"name" => "Farinha", "quantity" => 0.5, "unit" => "kg"}] = Pantry.list_items(user.id)
    end

    test "counts quantity without unit as the item's own unit", %{user: user} do
      add(user.id, "Leite", "1", "l")

      raw = "<USAGE>[{\"name\":\"Leite\",\"quantity\":0.3}]</USAGE>"

      {_cleaned, consumed, _low} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"name" => "Leite", "quantity" => 0.3, "unit" => "l"}] = consumed
      assert [%{"name" => "Leite", "quantity" => 0.7, "unit" => "l"}] = Pantry.list_items(user.id)
    end

    test "prefers the item whose unit matches the usage unit", %{user: user} do
      add(user.id, "Arroz", "500", "g")
      add(user.id, "Arroz", "1", "kg")

      raw = "<USAGE>[{\"name\":\"Arroz\",\"quantity\":0.5,\"unit\":\"kg\"}]</USAGE>"

      {_cleaned, consumed, _low} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"name" => "Arroz", "quantity" => 0.5, "unit" => "kg"}] = consumed

      items = Enum.sort_by(Pantry.list_items(user.id), & &1["quantity"])
      assert [%{"quantity" => 0.5, "unit" => "kg"}, %{"quantity" => 500.0, "unit" => "g"}] = items
    end

    test "skips usage with an unknown incompatible unit", %{user: user} do
      add(user.id, "Arroz", "1", "kg")

      raw = "<USAGE>[{\"name\":\"Arroz\",\"quantity\":2,\"unit\":\"xícaras\"}]</USAGE>"

      assert {_cleaned, [], []} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"quantity" => 1.0}] = Pantry.list_items(user.id)
    end

    test "caps deduction at the available quantity and flags out_of_stock", %{user: user} do
      add(user.id, "Sal", "2", "un")

      raw = "<USAGE>[{\"name\":\"Sal\",\"quantity\":5,\"unit\":\"un\"}]</USAGE>"

      {_cleaned, consumed, low} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"name" => "Sal", "quantity" => 2.0, "unit" => "un"}] = consumed
      assert [%{"name" => "Sal", "quantity" => 0, "unit" => "un", "out_of_stock" => true}] = low
      assert Pantry.list_items(user.id) == []
    end

    test "flags low stock without deleting the item", %{user: user} do
      add(user.id, "Sal", "3", "un")

      raw = "<USAGE>[{\"name\":\"Sal\",\"quantity\":2,\"unit\":\"un\"}]</USAGE>"

      {_cleaned, consumed, low} = Recipes.deduct(raw, pantry(user.id))
      assert [%{"name" => "Sal", "quantity" => 2.0, "unit" => "un"}] = consumed
      assert [%{"name" => "Sal", "quantity" => 1.0, "unit" => "un", "out_of_stock" => false}] = low
      assert [%{"quantity" => 1.0}] = Pantry.list_items(user.id)
    end

    test "ignores usage for ingredients not in the pantry", %{user: user} do
      add(user.id, "Sal", "1", "un")

      raw = "<USAGE>[{\"name\":\"Açafrão\",\"quantity\":1,\"unit\":\"un\"}]</USAGE>"

      assert {_cleaned, [], []} = Recipes.deduct(raw, pantry(user.id))
    end

    test "keeps text unchanged when there is no USAGE block", %{user: user} do
      raw = "Receita simples"
      assert {^raw, [], []} = Recipes.deduct(raw, pantry(user.id))
    end
  end

  describe "RecipeUsage" do
    test "week_window spans the user's local week", _context do
      {start_utc, end_utc} = Nutria.Usage.week_window()
      assert NaiveDateTime.compare(start_utc, end_utc) == :lt

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      assert NaiveDateTime.compare(now, start_utc) in [:gt, :eq]
      assert NaiveDateTime.compare(now, end_utc) in [:lt, :eq]
    end

    test "respects the weekly plan limit", %{user: user} do
      {:ok, user} = user |> Ecto.Changeset.change(plan: "folha") |> Nutria.Repo.update()

      assert RecipeUsage.can_generate?(user.id, :folha)

      for _ <- 1..3 do
        assert {:ok, _} = RecipeUsage.record_usage(user.id, :folha)
      end

      refute RecipeUsage.can_generate?(user.id, :folha)
      assert Recipes.remaining_recipes(user.id) == 0
    end

    test "soft limits for recipe counter are disabled in test env", _context do
      refute Nutria.Plans.soft_limits?()
    end
  end
end