defmodule NutriaWeb.ProfileLive.Index do
  @moduledoc """
  Mobile-style profile and settings page.
  """
  use NutriaWeb, :live_view

  on_mount({NutriaWeb.Live.AuthHelpers, :require_user})

  @avatar_accept ~w(.jpg .jpeg .png .webp .gif)
  @avatar_max_size 5_000_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_tab, "profile")
     |> allow_upload(:avatar,
       accept: @avatar_accept,
       max_entries: 1,
       max_file_size: @avatar_max_size,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate_avatar", _params, socket), do: {:noreply, socket}

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
            {:ok, updated} -> assign(socket, :current_user, updated)
            {:error, _} -> put_flash(socket, :error, "Não foi possível salvar a foto")
          end

        [{:error, message}] -> put_flash(socket, :error, message)
        _ -> put_flash(socket, :error, "Selecione um arquivo de imagem")
      end

    {:noreply, socket}
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
  defp avatar_url(avatar), do: "/uploads/avatars/" <> URI.encode(avatar)
  defp initial(user), do: user && user.name && user.name != "" && String.first(user.name) |> String.downcase() || "?"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view active screen-shell">
      <header class="chat-header">Perfil</header>

      <div class="profile-body">
        <div class="profile-inner">
          <div class="settings-profile-card screen-card">
            <div class="settings-avatar">
              <%= if url = avatar_url(@current_user.avatar) do %>
                <img src={url} alt="Foto de perfil" class="avatar-photo" />
              <% else %>
                <%= initial(@current_user) %>
              <% end %>
            </div>
            <div class="settings-user-name"><%= @current_user.name %></div>
            <div class="settings-user-email"><%= @current_user.email %></div>
            <div class="settings-provider-badge"><%= provider_label(@current_user.provider) %></div>
          </div>

          <button id="profile-theme-toggle" type="button" phx-hook="ThemeToggle" class="settings-theme-row theme-toggle screen-card">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon-sun"><circle cx="12" cy="12" r="5"></circle><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"></path></svg>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon-moon"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>
            <span class="settings-theme-label">Modo escuro</span>
            <span class="settings-theme-state theme-state"></span>
          </button>

          <div class="settings-profile-card screen-card">
            <div class="settings-user-name">Foto de perfil</div>
            <div class="settings-user-email">JPG, PNG, WebP ou GIF. Máximo 5 MB.</div>
            <form phx-change="validate_avatar" phx-submit="save_avatar" phx-drop-target={@uploads.avatar.ref} class="profile-upload-form">
              <.live_file_input upload={@uploads.avatar} class="hidden" />
              <button type="button" onclick={"document.getElementById('#{@uploads.avatar.ref}').click()"} class="settings-theme-row screen-card" style="justify-content:center">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                  <polyline points="17 8 21 4 17 0"></polyline>
                  <line x1="21" y1="4" x2="9" y2="16"></line>
                </svg>
                Trocar foto
              </button>
              <button type="submit" class="settings-theme-row screen-card" style="justify-content:center;background:var(--accent-soft);color:var(--accent)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
                  <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path>
                  <polyline points="17 21 17 13 7 13 7 21"></polyline>
                  <polyline points="7 3 7 8 15 8"></polyline>
                </svg>
                Salvar
              </button>
            </form>
          </div>

          <.link href={~p"/session/destroy"} method="delete" class="settings-logout-btn logout-link">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"></path>
            </svg>
            Sair da conta
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
