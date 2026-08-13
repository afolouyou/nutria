defmodule NutriaWeb.Router do
  use NutriaWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {NutriaWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :require_session_auth do
    plug(NutriaWeb.Plugs.AuthSessionPlug)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :require_auth do
    plug(NutriaWeb.Plugs.AuthPlug)
  end

  # LiveView routes
  scope "/" do
    pipe_through(:browser)

    get("/", NutriaWeb.RootController, :index)

    live("/login", NutriaWeb.LoginLive.Index, :index)

    scope "/" do
      pipe_through(:require_session_auth)

      live("/chat", NutriaWeb.ChatLive.Index, :index)
      live("/chat/:id", NutriaWeb.ChatLive.Index, :show)
      live("/pantry", NutriaWeb.PantryLive.Index, :index)
      live("/history", NutriaMobile.HistoryLive.Index, :index)
    end
  end

  # Session controller (form-based auth)
  scope "/" do
    pipe_through(:browser)

    get("/session/create", NutriaWeb.SessionController, :create)
    post("/session/create", NutriaWeb.SessionController, :create)
    post("/session/register", NutriaWeb.SessionController, :register)
    get("/session/destroy", NutriaWeb.SessionController, :destroy)
    delete("/session/destroy", NutriaWeb.SessionController, :destroy)
    get("/auth/google", NutriaWeb.SessionController, :google_auth)
    get("/auth/google/callback", NutriaWeb.SessionController, :google_callback)
  end

  # LiveDashboard (dev only)
  if Application.compile_env(:nutria_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/live_dashboard", metrics: NutriaWeb.Telemetry)
    end
  end

  # API routes (JSON - maintained)
  scope "/api" do
    pipe_through(:api)

    get("/", NutriaWeb.Controllers.AuthController, :root)
    post("/auth/register", NutriaWeb.Controllers.AuthController, :register)
    post("/auth/login", NutriaWeb.Controllers.AuthController, :login)
    post("/auth/social", NutriaWeb.Controllers.AuthController, :social)
    post("/auth/google", NutriaWeb.Controllers.AuthController, :google)

    scope "/" do
      pipe_through(:require_auth)

      get("/auth/me", NutriaWeb.Controllers.AuthController, :me)
      get("/conversations", NutriaWeb.Controllers.ConversationController, :index)
      get("/conversations/:id", NutriaWeb.Controllers.ConversationController, :show)
      delete("/conversations/:id", NutriaWeb.Controllers.ConversationController, :delete)
      post("/chat", NutriaWeb.Controllers.ChatController, :create)
      get("/pantry/items", NutriaWeb.Controllers.PantryController, :index)
      post("/pantry/items", NutriaWeb.Controllers.PantryController, :create)
      delete("/pantry/items/:id", NutriaWeb.Controllers.PantryController, :delete)
      post("/pantry/recipes", NutriaWeb.Controllers.PantryController, :recipes)
    end
  end
end
