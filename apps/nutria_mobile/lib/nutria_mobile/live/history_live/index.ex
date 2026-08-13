defmodule NutriaMobile.HistoryLive.Index do
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
     |> load_conversations()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_conversation", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Conversations.delete_conversation(id, user.id) do
      :ok ->
        {:noreply,
         socket
         |> load_conversations()
         |> assign(:conversations, Conversations.list_conversations(user.id))}

      {:error, _, msg} ->
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_conversations(socket)}
  end

  defp load_conversations(socket) do
    user = socket.assigns.current_user

    items =
      if user do
        Conversations.list_conversations(user.id)
      else
        []
      end

    socket
    |> assign(:items, items)
    |> assign(:loading, false)
  end

  defp format_date(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} ->
        Calendar.strftime(dt, "%d de %b., %H:%M", locale: :pt)

      _ ->
        iso_string
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <header class="px-6 py-4 border-b border-[#e9ecef] flex items-center gap-3">
        <h1 class="font-semibold text-base">Histórico de Conversas</h1>
      </header>

      <div class="flex-1 overflow-y-auto px-6 py-4">
        <div class="max-w-[720px] mx-auto">
          <%= if @loading do %>
            <div class="flex justify-center py-12">
              <div class="w-8 h-8 border-2 border-[#2d6a4f] border-t-transparent rounded-full animate-spin"></div>
            </div>
          <% else %>
            <%= if @items == [] do %>
              <div class="flex flex-col items-center py-12 text-center">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-14 h-14 text-[#ccc] mb-3">
                  <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>
                </svg>
                <p class="text-[#888] text-sm">Nenhuma conversa ainda</p>
                <p class="text-[#aaa] text-xs mt-1">Comece um chat para vê-lo aqui.</p>
              </div>
            <% else %>
              <div class="space-y-1.5">
                <%= for conv <- @items do %>
                  <div class="flex items-center gap-3 px-3 py-3 border border-[#dee2e6] rounded-xl bg-white hover:border-[#2d6a4f] transition-colors group">
                    <.link
                      navigate={~p"/chat/#{conv["id"]}"}
                      class="flex-1 min-w-0"
                    >
                      <div class="text-sm font-medium text-[#1a1a1a] truncate"><%= conv["title"] %></div>
                      <div class="text-xs text-[#888] mt-0.5"><%= format_date(conv["created_at"]) %></div>
                    </.link>
                    <button
                      phx-click="delete_conversation"
                      phx-value-id={conv["id"]}
                      class="p-1.5 text-[#888] hover:text-red-600 hover:bg-red-50 rounded-md transition-colors opacity-0 group-hover:opacity-100"
                    >
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                        <path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                      </svg>
                    </button>
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
