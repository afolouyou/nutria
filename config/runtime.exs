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

resolve_provider = fn
  "google" -> :google
  "zen" -> :zen
  "deepseek" -> :deepseek
  other -> String.to_atom(other)
end

config :nutria, :recipes, utc_offset_hours: String.to_integer(System.get_env("RECIPES_UTC_OFFSET", "-3"))

soft_limits =
  case System.get_env("PLANS_SOFT_LIMITS") do
    nil -> config_env() != :test
    value -> value != "false"
  end

config :nutria, :plans, soft_limits: soft_limits

config :nutria, :llm,
  google_api_key: System.get_env("GOOGLE_AI_KEY"),
  zen_api_key: System.get_env("ZEN_API_KEY"),
  deepseek_api_key: System.get_env("DEEPSEEK_API_KEY"),
  fast_provider: resolve_provider.(System.get_env("LLM_FAST_PROVIDER", "deepseek")),
  fast_model: System.get_env("LLM_FAST_MODEL", "deepseek-chat"),
  smart_provider: resolve_provider.(System.get_env("LLM_SMART_PROVIDER", "deepseek")),
  smart_model: System.get_env("LLM_SMART_MODEL", "deepseek-reasoner"),
  web_fetch_sites:
    System.get_env("WEB_FETCH_SITES",
      "allrecipes.com,allrecipes.com.br,seriouseats.com,epicurious.com,foodnetwork.com,bbcgoodfood.com,bonappetit.com,smittenkitchen.com,budgetbytes.com,tasty.co,tudogostoso.com.br"
    )
