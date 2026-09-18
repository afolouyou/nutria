defmodule Nutria.Recipes.RecipeUsage do
  @moduledoc """
  Tracks weekly recipe generation usage per plan.

  Limits come from `Nutria.Plans` (`:folha`/`:laranja` = 3/week). While
  `Nutria.Plans.soft_limits?/0` is enabled the counter resets instead of
  blocking (used during the preview fair).
  """
  use Ecto.Schema
  import Ecto.Query

  alias Nutria.Plans
  alias Nutria.Repo
  alias Nutria.Usage

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "recipe_usage" do
    belongs_to(:user, Nutria.Accounts.User)
    field(:used_at, :naive_datetime)

    timestamps(updated_at: false)
  end

  def can_generate?(user_id, plan) do
    case Plans.recipe_limit(plan) do
      nil -> true
      _limit -> remaining_this_week(user_id, plan) > 0 or Plans.soft_limits?()
    end
  end

  @doc "Remaining recipes this week, or `nil` when the plan is unlimited."
  def remaining_this_week(user_id, plan) do
    case Plans.recipe_limit(plan) do
      nil -> nil
      limit -> max(0, limit - count_week(user_id))
    end
  end

  def record_usage(user_id, plan) do
    case Plans.recipe_limit(plan) do
      nil ->
        :ok

      limit ->
        if count_week(user_id) >= limit, do: reset_week(user_id)
        insert_usage(user_id)
    end
  end

  def count_week(user_id) do
    {start_utc, end_utc} = Usage.week_window()

    Repo.aggregate(
      from(u in __MODULE__,
        where: u.user_id == ^user_id,
        where: u.used_at >= ^start_utc and u.used_at <= ^end_utc
      ),
      :count
    )
  end

  def reset_week(user_id) do
    {start_utc, end_utc} = Usage.week_window()

    Repo.delete_all(
      from(u in __MODULE__,
        where: u.user_id == ^user_id,
        where: u.used_at >= ^start_utc and u.used_at <= ^end_utc
      )
    )
  end

  defp insert_usage(user_id) do
    %__MODULE__{}
    |> Ecto.Changeset.change(%{
      user_id: user_id,
      used_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.insert()
  end
end
