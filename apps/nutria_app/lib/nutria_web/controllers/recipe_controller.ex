defmodule NutriaWeb.Controllers.RecipeController do
  use NutriaWeb, :controller

  alias Nutria.Plans
  alias Nutria.Recipes

  def remaining(conn, _params) do
    user_id = conn.assigns.current_user_id
    plan = Recipes.plan_of(user_id)

    json(conn, %{
      "plan" => Atom.to_string(plan),
      "remaining" => Recipes.remaining_recipes(user_id),
      "limit" => Plans.recipe_limit(plan),
      "window" => "week"
    })
  end
end
