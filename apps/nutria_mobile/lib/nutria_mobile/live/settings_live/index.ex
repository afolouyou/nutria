defmodule NutriaMobile.SettingsLive.Index do
  @moduledoc """
  User profile and settings page.
  """
  use NutriaWeb, :live_view

  on_mount({NutriaWeb.Live.AuthHelpers, :require_user})

  @avatar_accept ~w(.jpg .jpeg .png .webp .gif)
  @avatar_max_size 5_000_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:avatar,
       accept: @avatar_accept,
       max_entries: 1,
       max_file_size: @avatar_max_size
     )}
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

  def handle_event("validate_avatar", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_avatar", _params, socket) do
    user = socket.assigns.current_user

    results =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        case Nutria.Uploads.store(path, user.id) do
          {:ok, filename} -> {:ok, filename}
          {:error, _status, message} -> {:error, message}
        end
      end)

    socket =
      case results do
        [{:ok, filename}] ->
          Nutria.Uploads.delete(user.avatar)

          case Nutria.Accounts.update_avatar(user, filename) do
            {:ok, updated} ->
              socket
              |> assign(:current_user, updated)
              |> put_flash(:info, "Foto de perfil atualizada")

            {:error, _changeset} ->
              Nutria.Uploads.delete(filename)
              put_flash(socket, :error, "Não foi possível salvar a foto")
          end

        [{:error, message}] ->
          put_flash(socket, :error, message)

        _ ->
          put_flash(socket, :error, "Selecione um arquivo de imagem")
      end

    socket =
      Enum.reduce(socket.assigns.uploads.avatar.entries, socket, fn entry, acc ->
        cancel_upload(acc, :avatar, entry.ref)
      end)

    {:noreply, socket}
  end

  def handle_event("cancel_avatar", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  def handle_event("remove_avatar", _params, socket) do
    user = socket.assigns.current_user
    Nutria.Uploads.delete(user.avatar)

    case Nutria.Accounts.update_avatar(user, nil) do
      {:ok, updated} ->
        {:noreply, socket |> assign(:current_user, updated) |> put_flash(:info, "Foto de perfil removida")}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover a foto")}
    end
  end

  defp provider_label(provider) do
    case provider do
      "google" -> "Google"
      "apple" -> "Apple"
      _ -> "Email"
    end
  end

  defp avatar_url(nil), do: nil
  defp avatar_url(""), do: nil

  defp avatar_url(avatar) do
    "/uploads/avatars/" <> URI.encode(avatar)
  end

  defp initial(user) do
    user && user.name && user.name != "" && String.first(user.name) || "?"
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
            <div class="w-[70px] h-[70px] rounded-full bg-[#2d6a4f] text-white flex items-center justify-center text-2xl font-bold mx-auto mb-3 overflow-hidden">
              <%= if url = avatar_url(@current_user && @current_user.avatar) do %>
                <img src={url} alt="Foto de perfil" class="avatar-photo" />
              <% else %>
                <%= initial(@current_user) %>
              <% end %>
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

          <!-- Profile Photo -->
          <div>
            <h2 class="text-xs font-semibold text-[#888] uppercase tracking-wider mb-3">Foto de perfil</h2>
            <div class="bg-white border border-[#dee2e6] rounded-xl p-6">
              <div class="flex items-center gap-4">
                <div class="w-16 h-16 rounded-full bg-[#2d6a4f] text-white flex items-center justify-center text-xl font-bold flex-shrink-0 overflow-hidden">
                  <%= if url = avatar_url(@current_user && @current_user.avatar) do %>
                    <img src={url} alt="Foto de perfil" class="avatar-photo" />
                  <% else %>
                    <%= initial(@current_user) %>
                  <% end %>
                </div>
                <div class="text-sm text-[#666]">
                  JPG, PNG, WebP ou GIF. Máximo 5 MB.
                </div>
              </div>

              <form
                phx-change="validate_avatar"
                phx-submit="save_avatar"
                phx-drop-target={@uploads.avatar.ref}
                class="mt-5"
              >
                <div class="flex items-center gap-3">
                  <.live_file_input upload={@uploads.avatar} class="hidden" />
                  <button
                    type="button"
                    onclick={"document.getElementById('#{@uploads.avatar.ref}').click()"}
                    class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-[#dee2e6] rounded-lg text-sm font-medium text-[#333] hover:bg-[#f0f0f0] transition-colors"
                  >
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                      <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M17 8l-5-5-5 5M12 3v12"/>
                    </svg>
                    Trocar foto
                  </button>
                  <button
                    type="submit"
                    disabled={length(@uploads.avatar.entries) == 0}
                    class="inline-flex items-center px-4 py-2.5 bg-[#2d6a4f] text-white rounded-lg text-sm font-medium hover:bg-[#1b4332] transition-colors disabled:cursor-not-allowed"
                  >
                    Salvar
                  </button>
                  <%= if @current_user.avatar do %>
                    <button
                      type="button"
                      phx-click="remove_avatar"
                      class="inline-flex items-center gap-1.5 px-3 py-2.5 rounded-lg text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
                    >
                      Remover
                    </button>
                  <% end %>
                </div>

                <%= for entry <- @uploads.avatar.entries do %>
                  <div class="mt-3 text-sm text-[#555]">
                    <span class="font-medium"><%= entry.client_name %></span>
                    (<%= entry.client_size |> div(1024) %> KB)
                    <button type="button" phx-click="cancel_avatar" phx-value-ref={entry.ref} class="ml-2 text-red-600 hover:underline">
                      cancelar
                    </button>
                  </div>
                <% end %>

                <%= for err <- @uploads.avatar.errors do %>
                  <div class="mt-3 text-sm text-red-600"><%= error_to_string(err) %></div>
                <% end %>
              </form>
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

  defp error_to_string({:too_large, _}), do: "Arquivo muito grande (máximo 5 MB)"
  defp error_to_string({:not_accepted, _}), do: "Formato não aceito. Use JPG, PNG, WebP ou GIF"
  defp error_to_string({:too_many_files, _}), do: "Selecione apenas um arquivo"
  defp error_to_string(_), do: "Erro no arquivo"
end
