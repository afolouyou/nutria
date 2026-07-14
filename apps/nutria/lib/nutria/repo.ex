defmodule Nutria.Repo do
  use Ecto.Repo,
    otp_app: :nutria,
    adapter: Ecto.Adapters.Postgres
end
