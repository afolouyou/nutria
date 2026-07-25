defmodule NutriaWeb.LoginLive.Index do
  @moduledoc """
  Login and registration page.
  """
  use Phoenix.LiveView, layout: false

  import Phoenix.Component
  import Phoenix.LiveView

  import NutriaWeb.CoreComponents, only: [flash_group: 1]

  use NutriaWeb, :verified_routes
  alias Nutria.Accounts
  alias Nutria.Auth.Token

  @impl true
  def mount(_params, session, socket) do
    socket =
      case session do
        %{"auth_token" => token} when is_binary(token) ->
          case Token.verify_token(token) do
            {:ok, _} -> redirect(socket, to: "/chat")
            _ -> socket
          end

        _ ->
          socket
      end

    {:ok,
     socket
     |> assign(:mode, :login)
     |> assign(:email, "")
     |> assign(:password, "")
     |> assign(:name, "")
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_existing_atom(mode))}
  end

  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    field = String.to_existing_atom(field)
    {:noreply, assign(socket, field, value)}
  end

  def handle_event("submit_login", %{"email" => email, "password" => password}, socket) do
    socket = assign(socket, :loading, true)

    case Accounts.login(email, password) do
      {:ok, %{token: token}} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> redirect(to: "/session/create?token=#{token}")}

      {:error, _status, message} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, message)}
    end
  end

  def handle_event("submit_register", %{"email" => email, "password" => password, "name" => name}, socket) do
    socket = assign(socket, :loading, true)

    case Accounts.register(%{email: email, password: password, name: name}) do
      {:ok, %{token: token}} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> redirect(to: "/session/create?token=#{token}")}

      {:error, _status, message} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="login-page">
      <div class="login-card">
        <.flash_group flash={@flash} />
        <div class="login-logo">
          <img src={~p"/images/logo.svg"} alt="NutrIA" />
          <h1>NutrIA</h1>
          <p>A escolha inteligente para o seu prato</p>
        </div>

        <div class="login-tabs">
          <button
            phx-click="switch_mode"
            phx-value-mode="login"
            class={["login-tab", @mode == :login && "active"]}
          >
            Entrar
          </button>
          <button
            phx-click="switch_mode"
            phx-value-mode="register"
            class={["login-tab", @mode == :register && "active"]}
          >
            Cadastrar
          </button>
        </div>

        <%= if @mode == :login do %>
          <form phx-submit="submit_login" class="login-form">
            <input type="email" name="email" placeholder="Seu email" required autocomplete="email" class="login-input" />
            <input type="password" name="password" placeholder="Sua senha" required autocomplete="current-password" class="login-input" />
            <button type="submit" disabled={@loading} class="login-btn">
              <%= if @loading, do: "Entrando...", else: "Entrar" %>
            </button>
          </form>
        <% else %>
          <form phx-submit="submit_register" class="login-form">
            <input type="text" name="name" placeholder="Seu nome" required class="login-input" />
            <input type="email" name="email" placeholder="Seu email" required autocomplete="email" class="login-input" />
            <input type="password" name="password" placeholder="Crie uma senha" required autocomplete="new-password" class="login-input" />
            <button type="submit" disabled={@loading} class="login-btn">
              <%= if @loading, do: "Criando conta...", else: "Criar conta" %>
            </button>
          </form>
        <% end %>
      </div>
    </div>
    """
  end
end
