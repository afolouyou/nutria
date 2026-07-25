defmodule NutriaWeb.RootController do
  use NutriaWeb, :controller

  alias Nutria.Auth.Token

  def index(conn, _params) do
    case get_session(conn, "auth_token") do
      token when is_binary(token) ->
        case Token.verify_token(token) do
          {:ok, _user_id} -> redirect(conn, to: "/chat")
          _ -> redirect(conn, to: "/login")
        end

      _ ->
        redirect(conn, to: "/login")
    end
  end
end
