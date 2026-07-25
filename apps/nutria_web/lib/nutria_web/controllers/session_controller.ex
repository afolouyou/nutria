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

      {:error, :unauthorized, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: "/login")

      {:error, _status, message} ->
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

      {:error, _status, message} ->
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
end
