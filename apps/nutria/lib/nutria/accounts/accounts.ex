defmodule Nutria.Accounts do
  @moduledoc """
  Accounts context — user registration, login, social auth.
  """
  alias Nutria.Repo
  alias Nutria.Accounts.User
  alias Nutria.Auth.Token

  def register(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        {:ok, token} = Token.create_token(user.id)
        {:ok, %{user: user, token: token}}

      error ->
        format_error(error)
    end
  end

  def login(email, password) do
    email = email |> to_string() |> String.downcase()

    case Repo.get_by(User, email: email) do
      nil ->
        {:error, :unauthorized, "Email ou senha inválidos"}

      user ->
        if Bcrypt.verify_pass(password, user.password_hash || "") do
          {:ok, token} = Token.create_token(user.id)
          {:ok, %{user: user, token: token}}
        else
          {:error, :unauthorized, "Email ou senha inválidos"}
        end
    end
  end

  def social_login(email, name, provider) when provider in ["google", "apple"] do
    email = email |> to_string() |> String.downcase()

    user =
      case Repo.get_by(User, email: email) do
        nil ->
          %User{}
          |> User.changeset(%{
            email: email,
            name: name,
            provider: provider
          })
          |> Repo.insert!()

        existing ->
          existing
      end

    {:ok, token} = Token.create_token(user.id)
    {:ok, %{user: user, token: token}}
  end

  def social_login(_email, _name, provider) do
    {:error, :bad_request, "Provider inválido: #{provider}"}
  end

  def google_oauth_login(session_id) do
    url = "https://demobackend.emergentagent.com/auth/v1/env/oauth/session-data"

    case Req.get(url, headers: [{"X-Session-ID", session_id}], receive_timeout: 15_000) do
      {:ok, %Req.Response{status: 200, body: data}} ->
        email = (data["email"] || "") |> String.downcase()
        name = data["name"] || email |> String.split("@") |> List.first()

        social_login(email, name, "google")

      {:ok, %Req.Response{status: _status}} ->
        {:error, :unauthorized, "Sessão Google inválida"}

      {:error, reason} ->
        {:error, :bad_gateway, "Erro Google: #{inspect(reason)}"}
    end
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def user_to_map(%User{} = user) do
    %{
      "id" => user.id,
      "email" => user.email,
      "name" => user.name,
      "provider" => user.provider
    }
  end

  defp format_error({:error, %Ecto.Changeset{errors: errors}}) do
    message =
      errors
      |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
      |> Enum.join(", ")

    {:error, :bad_request, message}
  end

  defp format_error(error), do: error
end
