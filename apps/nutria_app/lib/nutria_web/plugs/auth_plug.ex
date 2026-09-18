defmodule NutriaWeb.Plugs.AuthPlug do
  @moduledoc """
  Plug for API auth — extracts Bearer JWT from Authorization header.
  """
  import Plug.Conn
  alias Nutria.Auth.Token
  alias Nutria.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case extract_token(conn) do
      {:ok, token} ->
        case Token.verify_token(token) do
          {:ok, user_id} ->
            case Accounts.get_user(user_id) do
              nil ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(401, Jason.encode!(%{"detail" => "User not found"}))
                |> halt()

              _user ->
                assign(conn, :current_user_id, user_id)
            end

          {:error, _reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(401, Jason.encode!(%{"detail" => "Invalid token"}))
            |> halt()
        end

      :error ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{"detail" => "Missing token"}))
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end
end
