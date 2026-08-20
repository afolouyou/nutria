import Config

config :nutria, Nutria.Repo,
  username: System.get_env("POSTGRES_USER", System.get_env("USER", "folou")),
  password: System.get_env("POSTGRES_PASSWORD", ""),
  socket_dir: System.get_env("POSTGRES_SOCKET_DIR", "/tmp/pgsocket"),
  database: System.get_env("POSTGRES_DB", "nutria_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :nutria_app, NutriaWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "dev-only-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-to-accept-it-ok",
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:nutria, ~w(--watch)]}
  ]

config :nutria_app, :dev_routes, true

config :logger, :console, format: "[$level] $message\n"
