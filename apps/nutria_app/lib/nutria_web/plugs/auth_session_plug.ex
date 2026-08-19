defmodule NutriaWeb.Plugs.AuthSessionPlug do
  @moduledoc """
  Plug for LiveView session-based auth.
  Reads JWT from session, verifies it, and injects current_user into conn.assigns.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Nutria.Auth.Token
  alias Nutria.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with [token] <- get_session(conn, "auth_token") |> List.wrap(),
         {:ok, user_id} <- Token.verify_token(token),
         %{} = user when not is_nil(user) <- Accounts.get_user(user_id) do
      conn
      |> assign(:current_user, user)
    else
      _ ->
        conn
        |> put_session(:redirect_reason, "auth_required")
        |> redirect(to: "/login")
        |> halt()
    end
  end
end
