defmodule NutriaWeb.SettingsLive.Index do
  @moduledoc """
  User profile and settings page.
  """
  use NutriaWeb, :live_view

  on_mount {NutriaWeb.Live.AuthHelpers, :require_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("logout", _params, socket) do
    {:noreply,
     socket
     |> redirect(to: "/session/destroy")}
  end

  defp provider_label(provider) do
    case provider do
      "google" -> "Google"
      "apple" -> "Apple"
      _ -> "Email"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <header class="px-6 py-4 border-b border-[#e9ecef]">
        <h1 class="font-semibold text-base">Perfil</h1>
      </header>

      <div class="flex-1 overflow-y-auto px-6 py-6">
        <div class="max-w-[480px] mx-auto space-y-8">
          <!-- Profile Card -->
          <div class="bg-white border border-[#dee2e6] rounded-xl p-6 text-center">
            <div class="w-[70px] h-[70px] rounded-full bg-[#2d6a4f] text-white flex items-center justify-center text-2xl font-bold mx-auto mb-3">
              <%= if @current_user, do: String.first(@current_user.name || "?"), else: "?" %>
            </div>
            <div class="text-lg font-semibold text-[#1a1a1a]" id="user-name">
              <%= @current_user && @current_user.name %>
            </div>
            <div class="text-sm text-[#666] mt-0.5" id="user-email">
              <%= @current_user && @current_user.email %>
            </div>
            <div class="mt-2">
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-[#f0f7f4] text-[#2d6a4f]">
                <%= @current_user && provider_label(@current_user.provider) %>
              </span>
            </div>
          </div>

          <!-- Account Section -->
          <div>
            <h2 class="text-xs font-semibold text-[#888] uppercase tracking-wider mb-3">Conta</h2>
            <div class="bg-white border border-[#dee2e6] rounded-xl overflow-hidden">
              <.link
                navigate={~p"/history"}
                class="flex items-center gap-3 px-4 py-3.5 border-b border-[#eee] hover:bg-[#f8f9fa] transition-colors"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5 text-[#666]">
                  <circle cx="12" cy="12" r="10"/>
                  <path d="M12 6v6l4 2"/>
                </svg>
                <span class="flex-1 text-sm text-[#333]">Histórico de conversas</span>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4 text-[#888]">
                  <path d="M9 18l6-6-6-6"/>
                </svg>
              </.link>

              <button
                phx-click="logout"
                class="flex items-center gap-3 px-4 py-3.5 w-full hover:bg-red-50 transition-colors text-left"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5 text-red-600">
                  <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9"/>
                </svg>
                <span class="flex-1 text-sm text-red-600 font-medium">Sair da conta</span>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4 text-red-400">
                  <path d="M9 18l6-6-6-6"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Footer -->
          <div class="text-center pb-8">
            <img src={~p"/images/logo.svg"} alt="NutrIA" class="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p class="text-xs text-[#aaa]">NutrIA - A escolha inteligente para o seu prato - v1.0</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
