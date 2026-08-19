defmodule NutriaWeb.SettingsDialogLive do
  @moduledoc """
  Settings popup (dialog) rendered in the app layout. Supports changing the
  profile photo via direct upload. Rendered as a nested LiveView so file
  uploads work inside the modal.
  """
  use NutriaWeb, :live_view

  @avatar_accept ~w(.jpg .jpeg .png .webp .gif)
  @avatar_max_size 5_000_000

  @impl true
  def mount(_params, session, socket) do
    case session["current_user_id"] do
      nil ->
        {:ok, assign(socket, :current_user, nil)}

      user_id ->
        case Nutria.Accounts.get_user(user_id) do
          nil ->
            {:ok, assign(socket, :current_user, nil)}

          user ->
            {:ok,
             socket
             |> assign(:current_user, user)
             |> assign(:form_message, nil)
             |> allow_upload(:avatar,
               accept: @avatar_accept,
               max_entries: 1,
               max_file_size: @avatar_max_size,
               auto_upload: true
             )}
        end
    end
  end

  @impl true
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
              notify_parent(socket, updated, :info, "Foto de perfil atualizada")
              assign(socket, :current_user, updated)

            {:error, _changeset} ->
              Nutria.Uploads.delete(filename)
              assign(socket, :form_message, "Não foi possível salvar a foto")
          end

        [{:error, message}] ->
          assign(socket, :form_message, message)

        _ ->
          assign(socket, :form_message, "Selecione um arquivo de imagem")
      end

    socket =
      Enum.reduce(socket.assigns.uploads.avatar.entries, socket, fn entry, acc ->
        cancel_upload(acc, :avatar, entry.ref)
      end)

    {:noreply, socket}
  end

  defp notify_parent(socket, user, kind, message) do
    if socket.parent_pid do
      send(socket.parent_pid, {:settings_avatar_updated, user, kind, message})
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
    <dialog id="settings-dialog" class="settings-dialog">
      <div class="settings-dialog-header">
        <h2 class="settings-dialog-title">Configurações</h2>
        <button class="settings-dialog-close" onclick="this.closest('dialog').close()" aria-label="Fechar">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
            <line x1="18" y1="6" x2="6" y2="18"/>
            <line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      <div class="settings-dialog-body">
        <%= if @current_user do %>
          <div class="settings-profile-card">
            <button
              type="button"
              class="settings-avatar"
              phx-drop-target={@uploads.avatar.ref}
              onclick={"document.getElementById('#{@uploads.avatar.ref}').click()"}
              aria-label="Trocar foto de perfil"
              title="Trocar foto de perfil"
            >
              <span class="settings-avatar-media">
                <%= if url = avatar_url(@current_user.avatar) do %>
                  <img src={url} alt="Foto de perfil" class="avatar-photo" />
                <% else %>
                  <%= initial(@current_user) %>
                <% end %>
              </span>
              <span class="settings-avatar-camera">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="22" height="22">
                  <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
                  <circle cx="12" cy="13" r="4"/>
                </svg>
              </span>
            </button>

            <form
              phx-change="validate_avatar"
              phx-submit="save_avatar"
              phx-drop-target={@uploads.avatar.ref}
            >
              <.live_file_input upload={@uploads.avatar} class="hidden" />
            </form>

            <div class="settings-user-name"><%= @current_user.name %></div>
            <div class="settings-user-email"><%= @current_user.email %></div>
            <div class="settings-provider-badge"><%= provider_label(@current_user.provider) %></div>

            <%= for err <- @uploads.avatar.errors do %>
              <div class="settings-photo-error"><%= error_to_string(err) %></div>
            <% end %>

            <%= if @form_message do %>
              <div class="settings-photo-error"><%= @form_message %></div>
            <% end %>
          </div>

          <button type="button" id="theme-toggle-settings" class="settings-theme-row" phx-hook="ThemeToggle">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon-sun"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon-moon"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
            <span class="settings-theme-label">Modo escuro</span>
            <span class="settings-theme-state"></span>
          </button>

          <.link href={~p"/session/destroy"} method="delete" class="settings-logout-btn">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18">
              <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9"/>
            </svg>
            Sair da conta
          </.link>
        <% else %>
          <p class="settings-photo-error">Sessão expirada. Faça login novamente.</p>
        <% end %>
      </div>
    </dialog>
    """
  end

  defp error_to_string({:too_large, _}), do: "Arquivo muito grande (máximo 5 MB)"
  defp error_to_string({:not_accepted, _}), do: "Formato não aceito. Use JPG, PNG, WebP ou GIF"
  defp error_to_string({:too_many_files, _}), do: "Selecione apenas um arquivo"
  defp error_to_string(_), do: "Erro no arquivo"
end
