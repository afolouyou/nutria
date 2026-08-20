defmodule NutriaWeb.HistoryLive.Index do
  @moduledoc """
  Conversation history list.
  """
  use NutriaWeb, :live_view

  on_mount({NutriaWeb.Live.AuthHelpers, :require_user})

  alias Nutria.Conversations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:items, [])
     |> assign(:loading, true)
     |> assign(:active_tab, "history")
     |> load_conversations()}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("delete_conversation", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Conversations.delete_conversation(id, user.id) do
      :ok -> {:noreply, socket |> load_conversations()}
      {:error, _, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  defp load_conversations(socket) do
    user = socket.assigns.current_user
    items = if user, do: Conversations.list_conversations(user.id), else: []
    socket |> assign(:items, items) |> assign(:loading, false)
  end

  defp format_date(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%d/%m, %H:%M")
      _ -> iso_string
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view active screen-shell">
      <header class="chat-header">
        <img src={~p"/images/logo-64.png"} alt="" class="header-logo" aria-hidden="true" />
        <span>Histórico</span>
      </header>

      <div class="screen-body">
        <div class="screen-inner">
          <%= if @loading do %>
            <div class="empty-state">Carregando...</div>
          <% else %>
            <%= if @items == [] do %>
              <div class="empty-state">Nenhuma conversa ainda</div>
            <% else %>
              <div class="history-list">
                <%= for conv <- @items do %>
                  <div class="history-row screen-card">
                    <.link navigate={~p"/chat/#{conv["id"]}"} class="row-main history-main">
                      <div class="row-title"><%= conv["title"] %></div>
                      <div class="row-subtitle"><%= format_date(conv["created_at"]) %></div>
                    </.link>
                    <button phx-click="delete_conversation" phx-value-id={conv["id"]} class="icon-btn" aria-label="Excluir conversa">✕</button>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
