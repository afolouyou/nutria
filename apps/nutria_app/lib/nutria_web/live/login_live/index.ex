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
      |> assign(:token, nil)
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

  def handle_event("submit_login", %{"email" => email, "password" => password}, socket) do
    socket = assign(socket, :loading, true)

    case Accounts.login(email, password) do
      {:ok, %{token: token}} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:token, token)
         |> assign(:trigger_action, true)}

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
    <img src={~p"/images/fundo.png"} alt="" class="bg-topo" aria-hidden="true" />

    <div class="login-page">
      <div class="login-card">
        <div class="login-logo">
          <img src={~p"/images/logo-512.png"} alt="NutrIA" />
          <h1>Nutr<em>IA</em></h1>
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

        <.flash_group flash={@flash} />

        <%= if @mode == :login do %>
          <.form
            for={nil}
            action={~p"/session/create"}
            method="post"
            class="login-form"
          >
            <input type="email" name="email" placeholder="Seu email" required autocomplete="email" class="login-input" />
            <input type="password" name="password" placeholder="Sua senha" required autocomplete="current-password" class="login-input" />
            <button type="submit" class="login-btn">
              Entrar
            </button>
          </.form>
        <% else %>
          <.form
            for={nil}
            action={~p"/session/register"}
            method="post"
            class="login-form"
          >
            <input type="text" name="name" placeholder="Seu nome" required class="login-input" />
            <input type="email" name="email" placeholder="Seu email" required autocomplete="email" class="login-input" />
            <input type="password" name="password" placeholder="Crie uma senha" required autocomplete="new-password" class="login-input" />
            <button type="submit" class="login-btn">
              Criar conta
            </button>
          </.form>
        <% end %>

        <div class="divider">ou</div>

        <a href={~p"/auth/google"} class="google-btn">
          <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path fill="#4285F4" d="M23.49 12.27c0-.79-.07-1.54-.19-2.27H12v4.51h6.47a5.57 5.57 0 0 1-2.4 3.58v3h3.86c2.26-2.09 3.56-5.17 3.56-8.82z"/>
            <path fill="#34A853" d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.86-3c-1.08.72-2.45 1.16-4.07 1.16-3.13 0-5.78-2.11-6.73-4.96H1.29v3.09A11.99 11.99 0 0 0 12 24z"/>
            <path fill="#FBBC05" d="M5.27 14.29A7.13 7.13 0 0 1 4.89 12c0-.8.14-1.57.38-2.29V6.62H1.29a11.97 11.97 0 0 0 0 10.76l3.98-3.09z"/>
            <path fill="#EA4335" d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.31 0 3.26 2.69 1.29 6.62l3.98 3.09C6.22 6.86 8.87 4.75 12 4.75z"/>
          </svg>
          Continuar com Google
        </a>
      </div>
    </div>
    """
  end
end
