defmodule NutriaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :nutria_app

  plug(Plug.Static,
    at: "/",
    from: :nutria_app,
    gzip: false,
    only: ~w(assets fonts images uploads favicon.ico robots.txt)
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(CORSPlug,
    origin: ["*"],
    allow_headers: ["content-type", "authorization"],
    allow_methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  )

  plug(NutriaWeb.Router)
end
