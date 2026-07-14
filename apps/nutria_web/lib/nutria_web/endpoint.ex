defmodule NutriaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :nutria_web

  @session_options [
    store: :cookie,
    key: "_nutria_web_key",
    signing_salt: "nutria",
    same_site: "Lax"
  ]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug CORSPlug, origin: ["*"], allow_headers: ["content-type", "authorization"], allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  plug NutriaWeb.Router
end
