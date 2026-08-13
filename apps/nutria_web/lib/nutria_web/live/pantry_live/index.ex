defmodule NutriaWeb.PantryLive.Index do
  @moduledoc """
  Pantry management and AI recipe generation.
  """
  use NutriaWeb, :live_view

  on_mount({NutriaWeb.Live.AuthHelpers, :require_user})

  alias Nutria.Pantry
  alias Nutria.Recipes

  @units ["g", "kg", "ml", "l", "un"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:items, [])
     |> assign(:name, "")
     |> assign(:qty, "")
     |> assign(:unit, "kg")
     |> assign(:notes, "")
     |> assign(:loading, false)
     |> assign(:adding, false)
     |> assign(:result, nil)
     |> assign(:units, @units)
     |> load_items()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, String.to_existing_atom(field), value)}
  end

  def handle_event("select_unit", %{"unit" => unit}, socket) do
    {:noreply, assign(socket, :unit, unit)}
  end

  def handle_event("add_item", _params, socket) do
    user = socket.assigns.current_user
    name = socket.assigns.name |> String.trim()
    qty_str = socket.assigns.qty |> String.trim() |> String.replace(",", ".")
    unit = socket.assigns.unit

    case Float.parse(qty_str) do
      {qty, ""} when qty > 0 ->
        socket = assign(socket, :adding, true)

        case Pantry.add_item(user.id, %{"name" => name, "quantity" => qty, "unit" => unit}) do
          {:ok, _item} ->
            {:noreply,
             socket
             |> assign(:adding, false)
             |> assign(:name, "")
             |> assign(:qty, "")
             |> load_items()}

          {:error, _, message} ->
            {:noreply,
             socket
             |> assign(:adding, false)
             |> put_flash(:error, message)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Quantidade inválida")}
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Pantry.delete_item(id, user.id) do
      :ok -> {:noreply, load_items(socket)}
      {:error, _, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("generate_recipe", _params, socket) do
    user = socket.assigns.current_user
    socket = assign(socket, :loading, true)

    Task.async(fn ->
      case Recipes.generate_from_pantry(user.id, socket.assigns.notes) do
        {:ok, result} -> {:recipe_done, result}
        {:error, _, msg} -> {:recipe_error, msg}
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:recipe_done, result}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:result, result)
     |> load_items()}
  end

  def handle_info({:recipe_error, message}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> put_flash(:error, message)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  defp load_items(socket) do
    user = socket.assigns.current_user

    items =
      if user do
        Pantry.list_items(user.id)
      else
        []
      end

    assign(socket, :items, items)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <header class="px-6 py-4 border-b border-[#e9ecef]">
        <h1 class="font-semibold text-base">Minha Despensa</h1>
      </header>

      <div class="flex-1 overflow-y-auto px-6 py-6">
        <div class="max-w-[720px] mx-auto space-y-6">
          <!-- Add Item Form -->
          <div class="bg-[#f0f0f0] border border-[#dee2e6] rounded-xl p-4">
            <h2 class="text-sm font-semibold text-[#333] mb-3">Adicionar item</h2>
            <form phx-submit="add_item" class="space-y-3">
              <input
                type="text"
                name="name"
                value={@name}
                placeholder="Ex.: Arroz"
                phx-change="update_field"
                phx-value-field="name"
                class="w-full px-3 py-2.5 border border-[#dee2e6] rounded-lg text-sm bg-[#f8f9fa] focus:border-[#2d6a4f] focus:bg-white outline-none transition-colors"
              />
              <div class="flex gap-3">
                <input
                  type="text"
                  name="qty"
                  value={@qty}
                  placeholder="Quantidade"
                  phx-change="update_field"
                  phx-value-field="qty"
                  class="flex-1 px-3 py-2.5 border border-[#dee2e6] rounded-lg text-sm bg-[#f8f9fa] focus:border-[#2d6a4f] focus:bg-white outline-none transition-colors"
                />
                <div class="flex gap-1">
                  <%= for u <- @units do %>
                    <button
                      type="button"
                      phx-click="select_unit"
                      phx-value-unit={u}
                      class={[
                        "w-10 h-10 rounded-lg text-xs font-medium transition-colors",
                        if(@unit == u,
                          do: "bg-[#2d6a4f] text-white",
                          else: "bg-[#f8f9fa] text-[#555] hover:bg-[#e9ecef]"
                        )
                      ]}
                    >
                      <%= u %>
                    </button>
                  <% end %>
                </div>
              </div>
              <button
                type="submit"
                disabled={@adding or @name == "" or @qty == ""}
                class="w-full py-2.5 bg-[#2d6a4f] text-white rounded-lg text-sm font-medium hover:bg-[#1b4332] transition-colors disabled:cursor-not-allowed flex items-center justify-center gap-2"
                style="background-color: #2d6a4f"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-4 h-4">
                  <circle cx="12" cy="12" r="10"/>
                  <path d="M12 8v8M8 12h8"/>
                </svg>
                <%= if @adding, do: "Adicionando...", else: "Adicionar à despensa" %>
              </button>
            </form>
          </div>

          <!-- Items List -->
          <div>
            <h2 class="text-xs font-semibold text-[#888] uppercase tracking-wider mb-2">
              Itens (<%= length(@items) %>)
            </h2>

            <%= if @items == [] do %>
              <div class="flex flex-col items-center py-12 text-center">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-14 h-14 text-[#ccc] mb-3">
                  <path d="M21 8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/>
                  <polyline points="3.27 6.96 12 12.01 20.73 6.96"/>
                  <line x1="12" y1="22.08" x2="12" y2="12"/>
                </svg>
                <p class="text-[#888] text-sm">Despensa vazia</p>
                <p class="text-[#aaa] text-xs mt-1">Adicione itens acima para começar.</p>
              </div>
            <% else %>
              <div class="space-y-1.5">
                <%= for item <- @items do %>
                  <div class={[
                    "flex items-center gap-3 px-3 py-3 rounded-xl border transition-colors group",
                    if(item["low_stock"],
                      do: "border-[#fc7100] bg-[#fff8f0]",
                      else: "border-[#dee2e6] bg-white hover:border-[#2d6a4f]"
                    )
                  ]}>
                    <div class="flex-1 min-w-0">
                      <span class="text-sm font-medium text-[#1a1a1a]"><%= item["name"] %></span>
                      <span class="text-sm text-[#666] ml-2">
                        <%= item["quantity"] %> <%= item["unit"] %>
                      </span>
                    </div>
                    <%= if item["low_stock"] do %>
                      <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-[#ffe6d2] text-[#fc7100]">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-3 h-3">
                          <path d="M12 9v4M12 17h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                        </svg>
                        Acabando
                      </span>
                    <% end %>
                    <button
                      phx-click="delete_item"
                      phx-value-id={item["id"]}
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
          </div>

          <!-- Notes -->
          <div>
            <textarea
              name="notes"
              value={@notes}
              placeholder="Observações para a receita (opcional)"
              phx-change="update_field"
              phx-value-field="notes"
              rows="3"
              class="w-full px-3 py-2.5 border border-[#dee2e6] rounded-lg text-sm bg-[#f8f9fa] focus:border-[#2d6a4f] focus:bg-white outline-none transition-colors resize-none"
            />
          </div>

          <!-- Generate Button -->
          <button
            phx-click="generate_recipe"
            disabled={@loading or @items == []}
            class="w-full py-2.5 bg-[#fc7100] text-white rounded-lg text-sm font-medium hover:bg-[#e06500] transition-colors disabled:cursor-not-allowed flex items-center justify-center gap-2"
            style="background-color: #fc7100"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5">
              <path d="M12 3l1.5 4.5L18 9l-4.5 1.5L12 15l-1.5-4.5L6 9l4.5-1.5z"/>
              <path d="M18 14l1 3 3 1-3 1-1 3-1-3-3-1 3-1z"/>
            </svg>
            <%= if @loading, do: "Gerando receita...", else: "Gerar receita com IA" %>
          </button>

          <!-- Recipe Result -->
          <%= if @result do %>
            <div class="bg-white border border-[#dee2e6] rounded-xl p-5">
              <div class="flex items-center gap-2 mb-3">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="w-5 h-5 text-[#2d6a4f]">
                  <path d="M3 3h18v18H3zM3 9h18M9 3v18"/>
                </svg>
                <h3 class="font-semibold text-[#1a1a1a]">Receita do NutrIA</h3>
              </div>
              <div class="text-sm text-[#333] leading-relaxed whitespace-pre-wrap mb-4">
                <%= @result["suggestions"] %>
              </div>

              <%= if @result["consumed"] != [] do %>
                <div class="bg-[#f0f7f4] rounded-lg p-3">
                  <h4 class="text-xs font-semibold text-[#2d6a4f] uppercase tracking-wider mb-2">Consumido da despensa</h4>
                  <div class="space-y-1">
                    <%= for item <- @result["consumed"] do %>
                      <div class="text-sm text-[#333]">
                        <%= item["name"] %> — <%= item["quantity"] %> <%= item["unit"] %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
