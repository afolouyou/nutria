import Config

config :nutria, Nutria.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :joken,
  default_signer: System.get_env("JWT_SECRET", "dev-secret-change-in-production")

config :nutria, :llm,
  google_api_key: System.get_env("GOOGLE_AI_KEY"),
  zen_api_key: System.get_env("ZEN_API_KEY"),
  fast_provider: System.get_env("LLM_FAST_PROVIDER", "google") |> String.to_existing_atom(),
  fast_model: System.get_env("LLM_FAST_MODEL", "gemma-4-31b-it"),
  smart_provider: System.get_env("LLM_SMART_PROVIDER", "zen") |> String.to_existing_atom(),
  smart_model: System.get_env("LLM_SMART_MODEL", "deepseek-v4-flash-free")
