defmodule Nutria.Recipes do
  @moduledoc """
  Recipes context — generate recipes from pantry and deduct consumed ingredients.
  """
  require Logger
  alias Nutria.Accounts
  alias Nutria.Pantry
  alias Nutria.Pantry.PantryItem
  alias Nutria.Plans
  alias Nutria.Recipes.RecipeUsage

  def generate_from_pantry(user_id, notes \\ nil, mode \\ :fast) do
    plan = plan_of(user_id)

    unless RecipeUsage.can_generate?(user_id, plan) do
      {:error, :too_many_requests, "Limite de receitas da semana atingido. Assine um plano para continuar."}
    else
      items = Pantry.get_all_items_for_user(user_id)

      if items == [] do
        {:error, :bad_request, "Sua despensa está vazia. Adicione ingredientes primeiro."}
      else
        inventory_text =
          items
          |> Enum.map(fn i -> "- #{i.name}: #{i.quantity} #{i.unit}" end)
          |> Enum.join("\n")

        case Nutria.LLM.recipe(inventory_text, notes, mode) do
          {:ok, raw_text} ->
            {cleaned_text, consumed, low_stock} = deduct(raw_text, items)
            {card_text, recipe, decoded?} = parse_recipe_block(cleaned_text)

            if decoded? or consumed != [] do
              RecipeUsage.record_usage(user_id, plan)
            end

            {:ok,
             %{
               "suggestions" => card_text,
               "recipe" => recipe,
               "consumed" => consumed,
               "low_stock" => low_stock
             }}

          {:error, _, detail} ->
            {:error, :bad_gateway, detail}
        end
      end
    end
  end

  def remaining_recipes(user_id) do
    RecipeUsage.remaining_this_week(user_id, plan_of(user_id))
  end

  def plan_of(user_id) do
    case Accounts.get_user(user_id) do
      nil -> :free
      user -> Plans.plan_of(user)
    end
  end

  @doc """
  Parses the `<USAGE>...</USAGE>` block of a raw LLM response and deducts the
  consumed ingredients from the pantry (converting compatible units).
  Returns `{cleaned_text, consumed, low_stock}`. Public for testing.
  """
  def deduct(raw_text, items) do
    case Regex.run(~r/<USAGE>(.*?)<\/USAGE>/s, raw_text) do
      [full_match, usage_json] ->
        cleaned_text = raw_text |> String.replace(full_match, "") |> String.trim()
        by_name = group_items_by_name(items)

        {consumed, low_stock} =
          case Jason.decode(usage_json) do
            {:ok, usage_list} when is_list(usage_list) ->
              Enum.reduce(usage_list, {[], []}, fn u, {consumed_acc, low_acc} ->
                name =
                  case u do
                    %{"name" => n} when is_binary(n) -> n |> String.trim() |> String.downcase()
                    _ -> ""
                  end

                qty = parse_qty(u)

                if name != "" and qty > 0 do
                  case resolve_item(by_name, name, u) do
                    nil ->
                      {consumed_acc, low_acc}

                    item ->
                      apply_deduction(item, u, qty, consumed_acc, low_acc)
                  end
                else
                  {consumed_acc, low_acc}
                end
              end)
              |> then(fn {consumed, low} -> {Enum.reverse(consumed), Enum.reverse(low)} end)

            _ ->
              {[], []}
          end

        {cleaned_text, consumed, low_stock}

      nil ->
        {raw_text, [], []}
    end
  end

  @unit_scale %{"kg" => 1000.0, "g" => 1.0, "l" => 1000.0, "ml" => 1.0, "un" => 1.0}

  defp base_unit(unit) do
    case unit do
      u when u in ["g", "kg"] -> :mass
      u when u in ["ml", "l"] -> :volume
      "un" -> :count
      _ -> nil
    end
  end

  defp group_items_by_name(items) do
    Enum.reduce(items, %{}, fn i, acc ->
      key = String.downcase(i.name)
      Map.update(acc, key, [i], &[i | &1])
    end)
  end

  defp resolve_item(by_name, name, u) do
    case Map.get(by_name, name) do
      nil ->
        nil

      candidates ->
        usage_unit = usage_unit_of(u)

        if usage_unit == "" do
          Enum.max_by(candidates, & &1.quantity)
        else
          case Enum.find(candidates, &normalize_unit(&1.unit) == usage_unit) do
            nil ->
              case base_unit(usage_unit) do
                nil -> nil
                base -> Enum.find(candidates, fn c -> base_unit(c.unit) == base end)
              end

            item ->
              item
          end
        end
    end
  end

  defp usage_unit_of(u) do
    case u do
      %{"unit" => unit} when is_binary(unit) ->
        unit |> String.trim() |> String.downcase()

      _ ->
        ""
    end
  end

  defp normalize_unit(unit), do: String.downcase(unit)

  defp apply_deduction(item, u, qty, consumed_acc, low_acc) do
    converted = convert_to_item_unit(qty, Map.get(u, "unit"), item.unit)
    actual = min(converted, item.quantity)
    new_qty = max(0.0, item.quantity - actual)

    consumed_entry = %{
      "name" => item.name,
      "quantity" => Float.round(actual, 3),
      "unit" => item.unit
    }

    new_low =
      cond do
        new_qty <= 0 ->
          Pantry.update_quantity(item.id, 0)

          [
            %{"name" => item.name, "quantity" => 0, "unit" => item.unit, "out_of_stock" => true}
            | low_acc
          ]

        true ->
          Pantry.update_quantity(item.id, new_qty)

          if PantryItem.low_stock?(new_qty, item.unit) do
            [
              %{"name" => item.name, "quantity" => new_qty, "unit" => item.unit, "out_of_stock" => false}
              | low_acc
            ]
          else
            low_acc
          end
      end

    {[consumed_entry | consumed_acc], new_low}
  end

  defp parse_qty(%{"quantity" => q}) when is_number(q), do: q

  defp parse_qty(%{"quantity" => q}) when is_binary(q) do
    q = q |> String.trim() |> String.replace(",", ".")

    case Float.parse(q) do
      {f, _} when f > 0 -> f
      _ -> 0
    end
  end

  defp parse_qty(_), do: 0

  defp convert_to_item_unit(qty, usage_unit, item_unit) do
    usage_unit =
      case usage_unit do
        unit when is_binary(unit) and unit != "" -> unit |> String.trim() |> String.downcase()
        _ -> item_unit
      end

    case {Map.get(@unit_scale, usage_unit), Map.get(@unit_scale, item_unit)} do
      {usage_scale, item_scale} when is_number(usage_scale) and is_number(item_scale) ->
        qty * (usage_scale / item_scale)

      _ ->
        qty
    end
  end

  defp parse_recipe_block(text) do
    case Regex.run(~r/<RECIPE>(.*?)<\/RECIPE>/s, text) do
      [full, recipe_json] ->
        cleaned = String.replace(text, full, "")
        {recipe, decoded?} = decoded_recipe(recipe_json, cleaned)
        {cleaned, recipe, decoded?}

      nil ->
        {text, fallback_recipe(text), false}
    end
  end

  defp decoded_recipe(recipe_json, fallback_text) do
    case Jason.decode(recipe_json) do
      {:ok, recipe} when is_map(recipe) ->
        recipe =
          if is_binary(recipe["ingredients"]) do
            Map.put(recipe, "ingredients", [recipe["ingredients"]])
          else
            recipe
          end

        {normalized_recipe(recipe), true}

      _ ->
        {fallback_recipe(fallback_text), false}
    end
  end

  defp normalized_recipe(recipe) do
    %{
      "name" => recipe["name"] || fallback_name(recipe["ingredients"]),
      "description" => recipe["description"],
      "image" => nil,
      "prep_min" => as_nonneg_int(recipe["prep_min"]),
      "cook_min" => as_nonneg_int(recipe["cook_min"]),
      "total_min" => nil,
      "servings" => as_nonneg_int(recipe["servings"]),
      "ingredients" => list_of_strings(recipe["ingredients"]),
      "steps" => list_of_strings(recipe["steps"]),
      "nutrition" => list_of_maps(recipe["nutrition"]),
      "source" => "NutrIA",
      "source_url" => nil
    }
  end

  defp fallback_recipe(text) do
    name =
      text
      |> String.split("\n")
      |> Enum.find_value(&extract_heading_name/1) ||
        "Receita da despensa"

    ingredients = extract_list_between(text, "Ingredientes", "Modo de preparo")
    steps = extract_list_between(text, "Modo de preparo", nil)

    %{
      "name" => name,
      "description" => nil,
      "image" => nil,
      "prep_min" => nil,
      "cook_min" => nil,
      "total_min" => nil,
      "servings" => nil,
      "ingredients" => ingredients,
      "steps" => steps,
      "nutrition" => [],
      "source" => "NutrIA",
      "source_url" => nil
    }
  end

  defp extract_heading_name(line) do
    case Regex.run(~r/^(?:#+\s*|\*\*)?(.*?)(?:\*\*)?\s*$/u, line) do
      [_, name] ->
        name = String.trim(name)

        if name == "" or String.contains?(name, "Ingredientes") or
             String.contains?(name, "Modo de preparo") or String.contains?(name, "USAGE") or
             String.contains?(name, "RECIPE") do
          nil
        else
          name
        end

      _ ->
        nil
    end
  end

  defp extract_list_between(text, start_marker, end_marker) do
    parts = String.split(text, ~r/\n{1,}/)

    {list, _} =
      Enum.reduce(parts, {[], false}, fn part, {acc, capture} ->
        cond do
          String.contains?(part, start_marker) -> {acc, true}
          end_marker && String.contains?(part, end_marker) -> {acc, false}
          capture && String.match?(part, ~r/^[-*]\s/) -> {[String.trim(part) |> String.replace(~r/^[-*]\s*/, "") | acc], capture}
          capture && start_marker != "Modo de preparo" && String.match?(part, ~r/^\d+[.)]\s/) ->
            {[String.trim(part) |> String.replace(~r/^\d+[.)]\s*/, "") | acc], capture}
          true -> {acc, capture}
        end
      end)

    Enum.reverse(list)
  end

  defp as_nonneg_int(nil), do: nil
  defp as_nonneg_int(n) when is_integer(n), do: max(n, 0)
  defp as_nonneg_int(n) when is_binary(n), do: Float.parse(n) |> then(fn {f, _} -> trunc(f) end)
  defp as_nonneg_int(_), do: nil

  defp list_of_strings(nil), do: []
  defp list_of_strings(list) when is_list(list), do: Enum.map(list, &to_string/1)
  defp list_of_strings(_), do: []

  defp list_of_maps(nil), do: []
  defp list_of_maps(list) when is_list(list), do: Enum.filter(list, &is_map/1)
  defp list_of_maps(_), do: []

  defp fallback_name(_), do: "Receita da despensa"
end
