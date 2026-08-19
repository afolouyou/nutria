defmodule NutriaWeb.Live.AuthHelpers do
  @moduledoc """
  LiveView on_mount hooks for authentication.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Nutria.Auth.Token
  alias Nutria.Accounts
  alias Nutria.Conversations

  def on_mount(:require_user, _params, session, socket) do
    with [token] <- Map.get(session, "auth_token", []) |> List.wrap(),
         {:ok, user_id} <- Token.verify_token(token),
         %{} = user when not is_nil(user) <- Accounts.get_user(user_id) do
      conversations = Conversations.list_conversations(user_id)

      {:cont,
       socket
       |> assign(:current_user, user)
       |> assign(:conversations, conversations)}
    else
      _ ->
        {:halt, redirect(socket, to: "/login")}
    end
  end

  def on_mount(:maybe_user, _params, session, socket) do
    with [token] <- Map.get(session, "auth_token", []) |> List.wrap(),
         {:ok, user_id} <- Token.verify_token(token),
         %{} = user when not is_nil(user) <- Accounts.get_user(user_id) do
      {:cont,
       socket
       |> assign(:current_user, user)
       |> assign(:conversations, Conversations.list_conversations(user_id))}
    else
      _ ->
        {:cont,
         socket
         |> assign(:current_user, nil)
         |> assign(:conversations, [])}
    end
  end
end
