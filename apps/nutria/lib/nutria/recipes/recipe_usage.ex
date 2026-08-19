defmodule Nutria.Recipes.RecipeUsage do
  @moduledoc """
  Schema for tracking recipe generation usage (rate limiting).
  """
  use Ecto.Schema
  import Ecto.Query

  alias Nutria.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "recipe_usage" do
    belongs_to(:user, Nutria.Accounts.User)
    field(:used_at, :naive_datetime)

    timestamps(updated_at: false)
  end

  @daily_limit 5

  def can_generate?(user_id) do
    remaining_today(user_id) > 0
  end

  def remaining_today(user_id) do
    today_start = NaiveDateTime.utc_now() |> NaiveDateTime.beginning_of_day()
    today_end = NaiveDateTime.utc_now() |> NaiveDateTime.end_of_day()

    count =
      Repo.aggregate(
        from(u in __MODULE__,
          where: u.user_id == ^user_id,
          where: u.used_at >= ^today_start and u.used_at <= ^today_end
        ),
        :count
      )

    max(0, @daily_limit - count)
  end

  def record_usage(user_id) do
    %__MODULE__{}
    |> Ecto.Changeset.change(%{
      user_id: user_id,
      used_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })
    |> Repo.insert()
  end
end
