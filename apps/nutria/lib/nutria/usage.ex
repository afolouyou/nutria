defmodule Nutria.Usage do
  @moduledoc """
  Time windows (in UTC) used to count usage limits, adjusted to the user's
  local day/week via `:recipes, :utc_offset_hours` (default -3, America/Sao_Paulo).
  """

  def offset_hours do
    Application.get_env(:nutria, :recipes, [])[:utc_offset_hours] || -3
  end

  @doc "UTC range for the current local day."
  def day_window do
    offset = offset_hours()
    local = now_local(offset)

    {
      local |> NaiveDateTime.beginning_of_day() |> to_utc(offset),
      local |> NaiveDateTime.end_of_day() |> to_utc(offset)
    }
  end

  @doc "UTC range for the current local week (Monday..Sunday)."
  def week_window do
    offset = offset_hours()
    local = now_local(offset)
    date = NaiveDateTime.to_date(local)
    monday = Date.add(date, -(Date.day_of_week(date) - 1))

    start_local = NaiveDateTime.new!(monday, ~T[00:00:00])
    finish_local = NaiveDateTime.new!(Date.add(monday, 6), ~T[23:59:59])

    {to_utc(start_local, offset), to_utc(finish_local, offset)}
  end

  defp now_local(offset) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.add(offset * 3600, :second)
  end

  defp to_utc(naive, offset) do
    naive
    |> NaiveDateTime.add(-offset * 3600, :second)
    |> NaiveDateTime.truncate(:second)
  end
end
