defmodule Nutria.Recipes do
  @moduledoc """
  Recipes context — generate recipes from pantry and deduct consumed ingredients.
  """
  require Logger
  alias Nutria.Pantry
  alias Nutria.Pantry.PantryItem

  def generate_from_pantry(user_id, notes \\ nil, mode \\ :fast) do
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
          {cleaned_text, consumed, low_stock} = parse_and_deduct(raw_text, items)

          {:ok,
           %{
             "suggestions" => cleaned_text,
             "consumed" => consumed,
             "low_stock" => low_stock
           }}

        {:error, _, detail} ->
          {:error, :bad_gateway, detail}
      end
    end
  end

  defp parse_and_deduct(raw_text, items) do
    case Regex.run(~r/<USAGE>(.*?)<\/USAGE>/s, raw_text) do
      [full_match, usage_json] ->
        cleaned_text = raw_text |> String.replace(full_match, "") |> String.trim()

        {consumed, low_stock} =
          case Jason.decode(usage_json) do
            {:ok, usage_list} when is_list(usage_list) ->
              by_norm = Map.new(items, fn i -> {String.downcase(i.name), i} end)

              usage_list
              |> Enum.reduce({[], []}, fn u, {consumed_acc, low_acc} ->
                key =
                  case u do
                    %{"name" => n} when is_binary(n) -> n |> String.trim() |> String.downcase()
                    _ -> ""
                  end

                qty =
                  case u do
                    %{"quantity" => q} when is_number(q) -> q
                    %{"quantity" => q} when is_binary(q) -> Float.parse(q) |> elem(0)
                    _ -> 0
                  end

                case by_norm do
                  %{^key => item} when qty > 0 ->
                    new_qty = max(0.0, item.quantity - qty)

                    consumed_entry = %{
                      "name" => item.name,
                      "quantity" => qty,
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
                              %{
                                "name" => item.name,
                                "quantity" => new_qty,
                                "unit" => item.unit,
                                "out_of_stock" => false
                              }
                              | low_acc
                            ]
                          else
                            low_acc
                          end
                      end

                    {[consumed_entry | consumed_acc], new_low}

                  _ ->
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
end
