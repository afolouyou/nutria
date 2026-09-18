defmodule Nutria.Tools.PantryTool do
  @moduledoc """
  PantryTool — lets the LLM modify the user's pantry via a `<PANTRY>...</PANTRY>`
  JSON block appended to its answer.

  Block format:
  ```xml
  <PANTRY>{"add":[{"name":"maçã","quantity":3,"unit":"un"},{"name":"leite","quantity":500,"unit":"ml","category":"Laticínios"}],"remove":[{"name":"arroz"},{"name":"feijão"}]}</PANTRY>
  ```

  `remove` matches pantry items by normalized name (case/accent-insensitive).
  """

  alias Nutria.Pantry.PantryItem
  alias Nutria.Repo
  import Ecto.Query

  @pattern ~r/<PANTRY>(.*?)<\/PANTRY>/s

  @doc "Pulls the pantry block out of a text, returning `{cleaned_text, json | nil}`."
  def extract(text) do
    case Regex.run(@pattern, text) do
      [full, json] ->
        cleaned = text |> String.replace(full, "") |> String.trim()
        {cleaned, json}

      nil ->
        {text, nil}
    end
  end

  @doc """
  Applies an extracted pantry JSON action.

  Returns `{:ok, %{"added" => [...], "removed" => [...]}}` with the affected items,
  or `{:error, :bad_request, detail}`.
  """
  def apply(user_id, json) do
    case Jason.decode(json) do
      {:ok, %{"add" => add} = action} when is_list(add) ->
        {removed, add_result} = do_apply(user_id, Map.get(action, "remove", []), add)
        {:ok, %{"added" => add_result, "removed" => removed}}

      {:ok, %{"remove" => remove} = action} when is_list(remove) ->
        {removed, _} = do_apply(user_id, remove, Map.get(action, "add", []))
        {:ok, %{"added" => [], "removed" => removed}}

      {:ok, %{} = action} ->
        {removed, _} = do_apply(user_id, Map.get(action, "remove", []), Map.get(action, "add", []))
        {:ok, %{"added" => [], "removed" => removed}}

      _ ->
        {:error, :bad_request, "Bloco PANTRY inválido"}
    end
  end

  defp do_apply(user_id, removes, adds) do
    removed = do_remove(user_id, removes)

    added =
      Enum.reduce(adds, [], fn raw, acc ->
        item = Map.take(raw, ["name", "quantity", "unit", "category"])

        if is_binary(item["name"]) and String.trim(item["name"]) != "" do
          case Nutria.Pantry.add_item(user_id, item) do
            {:ok, created} -> [created | acc]
            _ -> acc
          end
        else
          acc
        end
      end)

    {removed, Enum.reverse(added)}
  end

  defp do_remove(_user_id, removes) when not is_list(removes), do: []

  defp do_remove(user_id, removes) do
    Enum.reduce(removes, [], fn
      %{"name" => name}, acc when is_binary(name) ->
        do_remove_one(user_id, name, acc)

      _, acc ->
        acc
    end)
  end

  defp do_remove_one(user_id, name, acc) do
    norm = name |> String.trim() |> String.downcase()

    item =
      PantryItem
      |> where([p], p.user_id == ^user_id and p.name_norm == ^norm)
      |> limit(1)
      |> Repo.one()

    case item do
      nil ->
        acc

      found ->
        Nutria.Pantry.delete_item(found.id, user_id)
        [%{"id" => found.id, "name" => found.name, "quantity" => found.quantity, "unit" => found.unit} | acc]
    end
  end
end