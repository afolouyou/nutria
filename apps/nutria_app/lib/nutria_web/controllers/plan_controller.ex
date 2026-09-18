defmodule NutriaWeb.Controllers.PlanController do
  use NutriaWeb, :controller

  alias Nutria.Accounts
  alias Nutria.Chat.ChatUsage
  alias Nutria.Plans
  alias Nutria.Recipes

  def show(conn, _params) do
    user_id = conn.assigns.current_user_id

    plan =
      case Accounts.get_user(user_id) do
        nil -> :free
        user -> Plans.plan_of(user)
      end

    json(conn, %{
      "plan" => Atom.to_string(plan),
      "chat_remaining" => ChatUsage.remaining_today(user_id, plan),
      "chat_limit" => Plans.chat_limit(plan),
      "recipe_remaining" => Recipes.remaining_recipes(user_id),
      "recipe_limit" => Plans.recipe_limit(plan),
      "menu_remaining" => nil,
      "menu_limit" => Plans.menu_limit(plan),
      "soft_limits" => Plans.soft_limits?()
    })
  end
end
