defmodule Nutria.Auth.Google do
  @moduledoc """
  Google OAuth2 (OIDC) — authorization URL and code exchange using Req.
  """

  @authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://www.googleapis.com/oauth2/v3/userinfo"

  def client_id, do: config(:client_id)
  def client_secret, do: config(:client_secret)
  def redirect_uri, do: config(:redirect_uri)

  def auth_url(state) do
    query =
      URI.encode_query(%{
        client_id: client_id(),
        redirect_uri: redirect_uri(),
        response_type: "code",
        scope: "openid email profile",
        state: state,
        prompt: "select_account"
      })

    "#{@authorize_url}?#{query}"
  end

  def exchange_code(code) do
    body =
      URI.encode_query(%{
        code: code,
        client_id: client_id(),
        client_secret: client_secret(),
        redirect_uri: redirect_uri(),
        grant_type: "authorization_code"
      })

    case Req.post(@token_url,
           headers: [{"content-type", "application/x-www-form-urlencoded"}],
           body: body,
           receive_timeout: 15_000
         ) do
      {:ok, %Req.Response{status: 200, body: %{"access_token" => token}}} ->
        fetch_userinfo(token)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :unauthorized, "Erro Google (token): #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, :bad_gateway, "Erro Google: #{inspect(reason)}"}
    end
  end

  defp fetch_userinfo(token) do
    case Req.get(@userinfo_url,
           headers: [{"authorization", "Bearer #{token}"}],
           receive_timeout: 15_000
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        email = (body["email"] || "") |> String.downcase()
        name = body["name"] || body["given_name"] || email |> String.split("@") |> List.first()
        {:ok, %{email: email, name: name, picture: body["picture"]}}

      {:ok, %Req.Response{status: status}} ->
        {:error, :unauthorized, "Erro Google (perfil): #{status}"}

      {:error, reason} ->
        {:error, :bad_gateway, "Erro Google (perfil): #{inspect(reason)}"}
    end
  end

  defp config(key) do
    :nutria
    |> Application.get_env(:google_oauth, [])
    |> Keyword.fetch!(key)
  end
end
