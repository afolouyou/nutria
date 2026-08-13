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
     |> assign(:trigger_action, false)
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

  def handle_event(
        "submit_register",
        %{"email" => email, "password" => password, "name" => name},
        socket
      ) do
    socket = assign(socket, :loading, true)

    case Accounts.register(%{email: email, password: password, name: name}) do
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
    <div class="login-page">
      <button
        type="button"
        id="theme-toggle-login"
        class="theme-toggle theme-toggle-fab"
        phx-hook="ThemeToggle"
        aria-label="Alternar tema"
        title="Alternar tema"
      >
        <svg class="icon-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>
        <svg class="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      </button>
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
          <.form
            for={nil}
            action={~p"/session/create"}
            method="post"
            phx-submit="submit_login"
            phx-trigger-action={@trigger_action}
            class="login-form"
          >
            <input type="hidden" name="token" value={@token} />
            <input type="email" name="email" placeholder="Seu email" required autocomplete="email" class="login-input" />
            <input type="password" name="password" placeholder="Sua senha" required autocomplete="current-password" class="login-input" />
            <button type="submit" disabled={@loading} class="login-btn">
              <%= if @loading, do: "Entrando...", else: "Entrar" %>
            </button>
          </.form>
        <% else %>
          <.form
            for={nil}
            action={~p"/session/register"}
            method="post"
            phx-submit="submit_register"
            phx-trigger-action={@trigger_action}
            class="login-form"
          >
            <input type="hidden" name="token" value={@token} />
            <input type="text" name="name" placeholder="Seu nome" required class="login-input" />
            <input type="email" name="email" placeholder="Seu email" required autocomplete="email" class="login-input" />
            <input type="password" name="password" placeholder="Crie uma senha" required autocomplete="new-password" class="login-input" />
            <button type="submit" disabled={@loading} class="login-btn">
              <%= if @loading, do: "Criando conta...", else: "Criar conta" %>
            </button>
          </.form>
        <% end %>

        <div class="login-divider">
          <span>ou</span>
        </div>
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
