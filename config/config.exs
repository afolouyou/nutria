import Config

config :nutria,
  ecto_repos: [Nutria.Repo]

config :nutria, Nutria.Guardian,
  issuer: "nutria",
  secret_key: System.get_env("JWT_SECRET", "dev-secret-change-in-production")

config :nutria, Nutria.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :joken,
  default_signer: System.get_env("JWT_SECRET", "dev-secret-change-in-production")

config :nutria, :gemini,
  api_key: System.get_env("EMERGENT_LLM_KEY"),
  model: "gemini-3-flash-preview"

config :nutria_web, NutriaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: NutriaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Nutria.PubSub,
  live_view: [signing_salt: "nutria"]

config :nutria_web, :generators,
  context_app: :nutria

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
