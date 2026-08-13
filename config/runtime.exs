import Config

config :nutria, Nutria.Repo, pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

jwt_secret =
  case System.get_env("JWT_SECRET") do
    nil ->
      if config_env() == :prod do
        raise "JWT_SECRET deve ser definida em produção"
      else
        "dev-secret-change-in-production"
      end

    secret ->
      secret
  end

config :joken, default_signer: jwt_secret

config :nutria, :llm,
  google_api_key: System.get_env("GOOGLE_AI_KEY"),
  zen_api_key: System.get_env("ZEN_API_KEY"),
  fast_provider: System.get_env("LLM_FAST_PROVIDER", "google") |> String.to_existing_atom(),
  fast_model: System.get_env("LLM_FAST_MODEL", "gemma-4-26b-a4b-it"),
  smart_provider: System.get_env("LLM_SMART_PROVIDER", "zen") |> String.to_existing_atom(),
  smart_model: System.get_env("LLM_SMART_MODEL", "deepseek-v4-flash-free")
