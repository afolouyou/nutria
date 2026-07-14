defmodule NutriaWeb.Plugs.AuthPlug do
  @moduledoc """
  Plug to extract and verify JWT from Authorization header.
  Sets `conn.assigns.current_user_id` on success.
  """
  import Plug.Conn

  alias Nutria.Auth.Token
  alias Nutria.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, user_id} <- Token.verify_token(token),
         %{} = user when not is_nil(user) <- Accounts.get_user(user_id) do
      conn
      |> assign(:current_user_id, user_id)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{"detail" => "Missing token"}))
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing}
    end
  end
end
