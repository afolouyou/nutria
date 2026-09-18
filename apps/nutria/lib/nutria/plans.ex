defmodule Nutria.Plans do
  @moduledoc """
  Central subscription/entitlement rules.

  Plans:
    * `:free`    — Grátis: chat limitado, sem cardápios.
    * `:folha`   — Pago 1 (R$ 9,99): receitas que descontam a despensa.
    * `:laranja` — Pago 2 (R$ 14,99): receitas + cardápio semanal.

  Limits are expressed as `nil` (unlimited) or a positive integer for the
  relevant window (day for chat, week for recipes/menus).

  While `soft_limits` is enabled (default during the preview fair) reaching a
  limit resets the counter instead of blocking access.
  """

  @plans [:free, :folha, :laranja]

  @chat_daily_limit %{free: 7, folha: nil, laranja: nil}
  @recipe_weekly_limit %{free: 5, folha: 3, laranja: 3}
  @menu_weekly_limit %{free: 0, folha: 0, laranja: 1}

  def all, do: @plans

  def normalize(nil), do: :free
  def normalize(plan) when plan in @plans, do: plan

  def normalize(plan) when is_binary(plan) do
    case plan do
      "free" -> :free
      "folha" -> :folha
      "laranja" -> :laranja
      _ -> :free
    end
  end

  def normalize(_), do: :free

  def normalize_to_string(nil), do: "free"
  def normalize_to_string(plan) when is_binary(plan), do: normalize(plan) |> Atom.to_string()
  def normalize_to_string(plan), do: normalize(plan) |> Atom.to_string()

  def plan_of(%{plan: plan}), do: normalize(plan)
  def plan_of(_), do: :free

  def chat_limit(plan), do: Map.fetch!(@chat_daily_limit, normalize(plan))
  def recipe_limit(plan), do: Map.fetch!(@recipe_weekly_limit, normalize(plan))
  def menu_limit(plan), do: Map.fetch!(@menu_weekly_limit, normalize(plan))

  def can_generate_menu?(plan), do: (menu_limit(plan) || 0) > 0

  @doc "When true, exhausted limits reset instead of blocking the user."
  def soft_limits? do
    Application.get_env(:nutria, :plans, [])[:soft_limits] != false
  end
end
