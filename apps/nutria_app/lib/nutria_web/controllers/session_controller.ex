defmodule NutriaWeb.SessionController do
  @moduledoc """
  Controller for form-based session management (login, register, logout).
  Used by LiveView pages that redirect to form submissions.
  """
  use NutriaWeb, :controller

  alias Nutria.Accounts

  def create(conn, %{"token" => token}) do
    conn
    |> put_session("auth_token", token)
    |> redirect(to: "/chat")
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.login(email, password) do
      {:ok, %{user: _user, token: token}} ->
        conn
        |> put_session("auth_token", token)
        |> redirect(to: "/chat")

      {:error, :not_found, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: "/login")

      {:error, :unauthorized, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: "/login")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Email e senha são obrigatórios")
    |> redirect(to: "/login")
  end

  def register(conn, %{"email" => email, "password" => password, "name" => name}) do
    case Accounts.register(%{email: email, password: password, name: name}) do
      {:ok, %{user: _user, token: token}} ->
        conn
        |> put_session("auth_token", token)
        |> redirect(to: "/chat")

      {:error, :bad_request, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: "/login")
    end
  end

  def register(conn, _params) do
    conn
    |> put_flash(:error, "Nome, email e senha são obrigatórios")
    |> redirect(to: "/login")
  end

  def destroy(conn, _params) do
    conn
    |> delete_session("auth_token")
    |> redirect(to: "/login")
  end

  def google_auth(conn, _params) do
    state = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    conn
    |> put_session("google_oauth_state", state)
    |> redirect(external: Nutria.Auth.Google.auth_url(state))
  end

  def google_callback(conn, %{"code" => code, "state" => state}) do
    if state != "" and state == get_session(conn, "google_oauth_state") do
      case Nutria.Auth.Google.exchange_code(code) do
        {:ok, %{email: email, name: name, picture: picture}} ->
          case Accounts.social_login(email, name, "google") do
            {:ok, %{user: user, token: token}} ->
              maybe_fetch_google_avatar(user, picture)

              conn
              |> delete_session("google_oauth_state")
              |> put_session("auth_token", token)
              |> redirect(to: "/chat")

            {:error, _status, message} ->
              conn
              |> delete_session("google_oauth_state")
              |> put_flash(:error, message)
              |> redirect(to: "/login")
          end

        {:error, _status, message} ->
          conn
          |> delete_session("google_oauth_state")
          |> put_flash(:error, message)
          |> redirect(to: "/login")
      end
    else
      conn
      |> delete_session("google_oauth_state")
      |> put_flash(:error, "Requisição de autenticação inválida")
      |> redirect(to: "/login")
    end
  end

  def google_callback(conn, _params) do
    conn
    |> delete_session("google_oauth_state")
    |> put_flash(:error, "Falha na autenticação com Google")
    |> redirect(to: "/login")
  end

  defp maybe_fetch_google_avatar(user, picture) do
    if user.avatar in [nil, ""] and is_binary(picture) and picture != "" do
      case Nutria.Uploads.fetch_remote(picture, user.id) do
        {:ok, filename} ->
          case Accounts.update_avatar(user, filename) do
            {:ok, updated} -> updated
            _ -> user
          end

        _ ->
          user
      end
    else
      user
    end
  end
end
