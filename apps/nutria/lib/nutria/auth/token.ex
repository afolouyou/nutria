defmodule Nutria.Auth.Token do
  @moduledoc """
  JWT token creation and verification using Joken/JOSE.
  """

  @token_expiry_days 30

  def create_token(user_id) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    claims = %{
      "sub" => user_id,
      "iat" => now,
      "exp" => now + @token_expiry_days * 24 * 60 * 60
    }

    secret = Application.get_env(:joken, :default_signer)
    signer = Joken.Signer.create("HS256", secret)

    case Joken.generate_and_sign(%{}, claims, signer) do
      {:ok, token, _claims} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  def verify_token(token) do
    secret = Application.get_env(:joken, :default_signer)
    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify(token, signer) do
      {:ok, %{"sub" => user_id}} -> {:ok, user_id}
      {:error, reason} -> {:error, reason}
    end
  end
end
