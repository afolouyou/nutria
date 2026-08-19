import Config

config :nutria,
  ecto_repos: [Nutria.Repo]

config :nutria, Nutria.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :joken,
  default_signer: System.get_env("JWT_SECRET", "dev-secret-change-in-production")

config :nutria, :google_oauth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  redirect_uri: System.get_env("GOOGLE_REDIRECT_URI", "http://localhost:4000/auth/google/callback")

config :nutria, :llm,
  google_api_key: System.get_env("GOOGLE_AI_KEY"),
  zen_api_key: System.get_env("ZEN_API_KEY"),
  fast_provider: :google,
  fast_model: "gemma-4-26b-a4b-it",
  smart_provider: :zen,
  smart_model: "deepseek-v4-flash-free"

config :nutria_app, NutriaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: NutriaWeb.ErrorHTML, json: NutriaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Nutria.PubSub,
  live_view: [signing_salt: "GMVZPjA0hGN3WgCB"]

config :nutria_app, :generators, context_app: :nutria

config :tailwind,
  version: "4.0.17",
  nutria: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/nutria_app/assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
