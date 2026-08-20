defmodule Nutria.Pantry do
  @moduledoc """
  Pantry context — CRUD for pantry items with merge/dedup on add.
  """
  import Ecto.Query

  alias Nutria.Repo
  alias Nutria.Pantry.PantryItem

  def list_items(user_id) do
    PantryItem
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], asc: p.name)
    |> limit(500)
    |> Repo.all()
    |> Enum.map(&item_to_map/1)
  end

  def add_item(user_id, attrs) do
    if quantity_too_long?(attrs) do
      {:error, :bad_request, "quantity: deve ter no maximo 4 caracteres"}
    else
      changeset = PantryItem.changeset(%PantryItem{}, Map.put(attrs, "user_id", user_id))

      if changeset.valid? do
        name_norm = Ecto.Changeset.get_field(changeset, :name_norm)
        unit = Ecto.Changeset.get_field(changeset, :unit)
        quantity = Ecto.Changeset.get_field(changeset, :quantity)
        category = Ecto.Changeset.get_field(changeset, :category) || "Outros"

        case Repo.get_by(PantryItem,
               user_id: user_id,
               name_norm: name_norm,
               unit: unit,
               category: category
             ) do
          nil ->
            case Repo.insert(changeset) do
              {:ok, item} -> {:ok, item_to_map(item)}
              error -> error
            end

          existing ->
            existing
            |> PantryItem.changeset(%{"quantity" => existing.quantity + quantity})
            |> Repo.update()
            |> case do
              {:ok, updated} -> {:ok, item_to_map(updated)}
              error -> error
            end
        end
      else
        errors =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        {:error, :bad_request, errors}
      end
    end
  end

  def delete_item(item_id, user_id) do
    case Repo.get_by(PantryItem, id: item_id, user_id: user_id) do
      nil ->
        {:error, :not_found, "Item não encontrado"}

      item ->
        Repo.delete(item)
        :ok
    end
  end

  def update_item(user_id, item_id, attrs) do
    if quantity_too_long?(attrs) do
      {:error, :bad_request, "quantity: deve ter no maximo 4 caracteres"}
    else
      case Repo.get_by(PantryItem, id: item_id, user_id: user_id) do
        nil ->
          {:error, :not_found, "Item não encontrado"}

        item ->
          item
          |> PantryItem.changeset(attrs)
          |> Repo.update()
          |> case do
            {:ok, updated} -> {:ok, item_to_map(updated)}

            {:error, changeset} ->
              errors =
                changeset.errors
                |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                |> Enum.join(", ")

              {:error, :bad_request, errors}

            error ->
              error
          end
      end
    end
  end

  def get_all_items_for_user(user_id) do
    PantryItem
    |> where([p], p.user_id == ^user_id)
    |> Repo.all()
  end

  def update_quantity(item_id, new_quantity) do
    case Repo.get(PantryItem, item_id) do
      nil ->
        nil

      item ->
        if new_quantity <= 0 do
          Repo.delete(item)
          :deleted
        else
          item
          |> PantryItem.changeset(%{"quantity" => new_quantity})
          |> Repo.update!()
        end
    end
  end

  defp item_to_map(%PantryItem{} = item) do
    %{
      "id" => item.id,
      "name" => item.name,
      "quantity" => item.quantity,
      "unit" => item.unit,
      "category" => item.category,
      "low_stock" => PantryItem.low_stock?(item.quantity, item.unit)
    }
  end

  defp quantity_too_long?(%{"quantity" => quantity}) when is_binary(quantity) do
    quantity
    |> String.trim()
    |> String.length()
    |> Kernel.>(4)
  end

  defp quantity_too_long?(_), do: false
end
