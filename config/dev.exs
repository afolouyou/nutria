import Config

config :nutria, Nutria.Repo,
  username: System.get_env("POSTGRES_USER", System.get_env("USER", "folou")),
  password: System.get_env("POSTGRES_PASSWORD", ""),
  socket_dir: System.get_env("POSTGRES_SOCKET_DIR", "/tmp/pgsocket"),
  database: System.get_env("POSTGRES_DB", "nutria_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :nutria_web, NutriaWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: false,
  debug_errors: false,
  secret_key_base: "dev-only-secret-key-base-that-is-at-least-64-bytes-long-for-phoenix-to-accept-it-ok",
  watchers: []

config :logger, :console, format: "[$level] $message\n"
