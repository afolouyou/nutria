import Config

config :nutria, Nutria.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :joken,
  default_signer: System.get_env("JWT_SECRET", "dev-secret-change-in-production")

config :nutria, :gemini,
  api_key: System.get_env("EMERGENT_LLM_KEY"),
  model: System.get_env("LLM_MODEL", "gemini-3-flash-preview")
