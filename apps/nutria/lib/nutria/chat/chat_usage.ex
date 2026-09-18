defmodule Nutria.Chat.ChatUsage do
  @moduledoc """
  Tracks chat message usage for rate limiting the free plan.

  While `Nutria.Plans.soft_limits?/0` is enabled the counter resets once the
  limit is reached instead of blocking access (used during the preview fair).
  """
  use Ecto.Schema
  import Ecto.Query

  alias Nutria.Plans
  alias Nutria.Repo
  alias Nutria.Usage

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_usage" do
    belongs_to(:user, Nutria.Accounts.User)
    field(:used_at, :naive_datetime)

    timestamps(updated_at: false)
  end

  @doc "Remaining chat messages today, or `nil` when the plan is unlimited."
  def remaining_today(user_id, plan) do
    case Plans.chat_limit(plan) do
      nil -> nil
      limit -> max(0, limit - count_today(user_id))
    end
  end

  @doc """
  Registers one chat message. Returns `{:ok, remaining}` (remaining may be
  `nil` for unlimited plans) or `{:blocked, 0}` when hard limits are active.
  """
  def consume(user_id, plan) do
    case Plans.chat_limit(plan) do
      nil ->
        {:ok, nil}

      limit ->
        count = count_today(user_id)

        cond do
          count < limit ->
            record_usage(user_id)
            {:ok, limit - count - 1}

          Plans.soft_limits?() ->
            reset_today(user_id)
            record_usage(user_id)
            {:ok, limit - 1}

          true ->
            {:blocked, 0}
        end
    end
  end

  def count_today(user_id) do
    {start_utc, end_utc} = Usage.day_window()

    Repo.aggregate(
      from(u in __MODULE__,
        where: u.user_id == ^user_id,
        where: u.used_at >= ^start_utc and u.used_at <= ^end_utc
      ),
      :count
    )
  end

  def reset_today(user_id) do
    {start_utc, end_utc} = Usage.day_window()

    Repo.delete_all(
      from(u in __MODULE__,
        where: u.user_id == ^user_id,
        where: u.used_at >= ^start_utc and u.used_at <= ^end_utc
      )
    )
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
