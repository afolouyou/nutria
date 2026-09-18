defmodule NutriaWeb.Router do
  use NutriaWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :require_auth do
    plug(NutriaWeb.Plugs.AuthPlug)
  end

  scope "/api" do
    pipe_through(:api)

    get("/", NutriaWeb.Controllers.AuthController, :root)
    post("/auth/register", NutriaWeb.Controllers.AuthController, :register)
    post("/auth/login", NutriaWeb.Controllers.AuthController, :login)
    post("/auth/social", NutriaWeb.Controllers.AuthController, :social)

    scope "/" do
      pipe_through(:require_auth)

      get("/auth/me", NutriaWeb.Controllers.AuthController, :me)
      get("/conversations", NutriaWeb.Controllers.ConversationController, :index)
      get("/conversations/:id", NutriaWeb.Controllers.ConversationController, :show)
      delete("/conversations/:id", NutriaWeb.Controllers.ConversationController, :delete)
      post("/chat", NutriaWeb.Controllers.ChatController, :create)
      post("/chat/stream", NutriaWeb.Controllers.ChatStreamController, :create)
      get("/pantry/items", NutriaWeb.Controllers.PantryController, :index)
      post("/pantry/items", NutriaWeb.Controllers.PantryController, :create)
      put("/pantry/items/:id", NutriaWeb.Controllers.PantryController, :update)
      delete("/pantry/items/:id", NutriaWeb.Controllers.PantryController, :delete)
      post("/pantry/recipes", NutriaWeb.Controllers.PantryController, :recipes)
      get("/recipes/remaining", NutriaWeb.Controllers.RecipeController, :remaining)
      get("/me/plan", NutriaWeb.Controllers.PlanController, :show)
      post("/avatar", NutriaWeb.Controllers.AvatarController, :create)
      delete("/avatar", NutriaWeb.Controllers.AvatarController, :delete)
    end
  end
end
