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
    <div class="view active">
      <header class="chat-header">Histórico</header>

      <div class="history-body">
        <div class="history-inner">
          <%= if @loading do %>
            <div class="pantry-empty">Carregando...</div>
          <% else %>
            <%= if @items == [] do %>
              <div class="pantry-empty">Nenhuma conversa ainda</div>
            <% else %>
              <div class="pantry-list">
                <%= for conv <- @items do %>
                  <div class="history-item pantry-item">
                    <.link navigate={~p"/chat/#{conv["id"]}"} class="p-name">
                      <%= conv["title"] %>
                      <div class="settings-user-email"><%= format_date(conv["created_at"]) %></div>
                    </.link>
                    <button phx-click="delete_conversation" phx-value-id={conv["id"]} class="p-remove">✕</button>
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
