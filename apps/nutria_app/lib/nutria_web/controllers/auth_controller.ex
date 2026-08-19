defmodule NutriaWeb.Controllers.AuthController do
  use NutriaWeb, :controller

  action_fallback(NutriaWeb.Controllers.FallbackController)

  def root(conn, _params) do
    json(conn, %{"app" => "NutrIA", "status" => "ok"})
  end

  def register(conn, %{"email" => email, "password" => password, "name" => name}) do
    case Nutria.Accounts.register(%{"email" => email, "password" => password, "name" => name}) do
      {:ok, %{user: user, token: token}} ->
        json(conn, %{
          "access_token" => token,
          "user" => Nutria.Accounts.user_to_map(user)
        })

      {:error, _, _} = error ->
        error
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Nutria.Accounts.login(email, password) do
      {:ok, %{user: user, token: token}} ->
        json(conn, %{
          "access_token" => token,
          "user" => Nutria.Accounts.user_to_map(user)
        })

      {:error, _, _} = error ->
        error
    end
  end

  def social(conn, %{"email" => email, "name" => name, "provider" => provider}) do
    case Nutria.Accounts.social_login(email, name, provider) do
      {:ok, %{user: user, token: token}} ->
        json(conn, %{
          "access_token" => token,
          "user" => Nutria.Accounts.user_to_map(user)
        })

      {:error, _, _} = error ->
        error
    end
  end

  def google(conn, %{"session_id" => session_id}) do
    case Nutria.Accounts.google_oauth_login(session_id) do
      {:ok, %{user: user, token: token}} ->
        json(conn, %{
          "access_token" => token,
          "user" => Nutria.Accounts.user_to_map(user)
        })

      {:error, _, _} = error ->
        error
    end
  end

  def me(conn, _params) do
    user_id = conn.assigns.current_user_id

    case Nutria.Accounts.get_user(user_id) do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{"detail" => "User not found"})

      user ->
        json(conn, Nutria.Accounts.user_to_map(user))
    end
  end
end
