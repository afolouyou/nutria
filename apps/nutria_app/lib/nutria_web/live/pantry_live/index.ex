defmodule NutriaWeb.PantryLive.Index do
  @moduledoc """
  Pantry management and AI recipe generation.
  """
  use NutriaWeb, :live_view

  on_mount({NutriaWeb.Live.AuthHelpers, :require_user})

  alias Nutria.Pantry
  alias Nutria.Recipes

  @units ["g", "kg", "ml", "l", "un"]
  @categories ["Mantimentos", "Refrigerados", "Hortifruti", "Temperos", "Outros"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
      |> assign(:items, [])
      |> assign(:name, "")
      |> assign(:qty, "")
      |> assign(:unit, "kg")
      |> assign(:category, "Outros")
      |> assign(:edit_item_id, nil)
      |> assign(:edit_name, "")
      |> assign(:edit_qty, "")
      |> assign(:edit_unit, "kg")
      |> assign(:edit_category, "Outros")
      |> assign(:edit_open, false)
      |> assign(:saving_edit, false)
      |> assign(:notes, "")
       |> assign(:loading, false)
       |> assign(:adding, false)
       |> assign(:result, nil)
       |> assign(:units, @units)
       |> assign(:categories, @categories)
       |> assign(:active_tab, "pantry")
       |> load_items()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_form", params, socket) do
    {:noreply,
     socket
     |> assign(:name, Map.get(params, "name", socket.assigns.name))
     |> assign(:qty, Map.get(params, "qty", socket.assigns.qty))
     |> assign(:unit, Map.get(params, "unit", socket.assigns.unit))
     |> assign(:category, Map.get(params, "category", socket.assigns.category))}
  end

  def handle_event("add_item", _params, socket) do
    user = socket.assigns.current_user
    name = socket.assigns.name |> String.trim()
    qty_str = socket.assigns.qty |> String.trim() |> String.replace(",", ".")
    unit = socket.assigns.unit
    category = socket.assigns.category

    cond do
      qty_str == "" ->
        {:noreply, put_flash(socket, :error, "Quantidade invalida")}

      not Regex.match?(~r/^\d+(\.\d+)?$/, qty_str) ->
        {:noreply, put_flash(socket, :error, "Quantidade deve conter apenas numeros")}

      true ->
        case Float.parse(qty_str) do
          {qty, ""} when qty > 0 ->
            socket = assign(socket, :adding, true)

            case Pantry.add_item(user.id, %{"name" => name, "quantity" => qty, "unit" => unit, "category" => category}) do
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
            {:noreply, put_flash(socket, :error, "Quantidade invalida")}
        end
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Pantry.delete_item(id, user.id) do
      :ok -> {:noreply, load_items(socket)}
      {:error, _, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("open_edit", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.items, &(&1["id"] == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Item não encontrado")}

      item ->
        {:noreply,
         socket
         |> assign(:edit_item_id, id)
         |> assign(:edit_name, item["name"])
         |> assign(:edit_qty, format_qty(item["quantity"]))
         |> assign(:edit_unit, item["unit"])
         |> assign(:edit_category, item["category"])
         |> assign(:edit_open, true)}
    end
  end

  def handle_event("close_edit", _params, socket) do
    {:noreply, assign(socket, :edit_open, false)}
  end

  def handle_event("update_edit_form", params, socket) do
    {:noreply,
     socket
     |> assign(:edit_name, Map.get(params, "name", socket.assigns.edit_name))
     |> assign(:edit_qty, Map.get(params, "qty", socket.assigns.edit_qty))
     |> assign(:edit_unit, Map.get(params, "unit", socket.assigns.edit_unit))
     |> assign(:edit_category, Map.get(params, "category", socket.assigns.edit_category))}
  end

  def handle_event("save_edit", _params, socket) do
    user = socket.assigns.current_user
    name = socket.assigns.edit_name |> String.trim()
    qty_str = socket.assigns.edit_qty |> String.trim() |> String.replace(",", ".")

    cond do
      qty_str == "" ->
        {:noreply, put_flash(socket, :error, "Quantidade invalida")}

      not Regex.match?(~r/^\d+(\.\d+)?$/, qty_str) ->
        {:noreply, put_flash(socket, :error, "Quantidade deve conter apenas numeros")}

      true ->
        case Float.parse(qty_str) do
          {qty, ""} when qty > 0 ->
            socket = assign(socket, :saving_edit, true)

            case Pantry.update_item(user.id, socket.assigns.edit_item_id, %{
                   "name" => name,
                   "quantity" => qty,
                   "unit" => socket.assigns.edit_unit,
                   "category" => socket.assigns.edit_category
                 }) do
              {:ok, _item} ->
                {:noreply,
                 socket
                 |> assign(:saving_edit, false)
                 |> assign(:edit_open, false)
                 |> load_items()}

              {:error, _, message} ->
                {:noreply,
                 socket
                 |> assign(:saving_edit, false)
                 |> put_flash(:error, message)}
            end

          _ ->
            {:noreply, put_flash(socket, :error, "Quantidade invalida")}
        end
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

  defp format_qty(quantity) when is_float(quantity) do
    if quantity == trunc(quantity), do: Integer.to_string(trunc(quantity)), else: :erlang.float_to_binary(quantity, [:compact, decimals: 2])
  end

  defp format_qty(quantity), do: to_string(quantity)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="view active screen-shell pantry-shell">
      <button :if={@edit_open} type="button" class="drawer-scrim" phx-click="close_edit" aria-label="Fechar edição" />

      <header class="chat-header">
        <span>Despensa</span>
      </header>

      <div class="pantry-body">
        <div class="pantry-inner">
          <p class="pantry-sub">Guarde o que você tem em casa, com quantidades, para controlar seus alimentos.</p>

          <form phx-submit="add_item" phx-change="update_form" class="pantry-form pantry-form-pill">
            <input
              type="text"
              name="name"
              value={@name}
              maxlength="30"
              placeholder="Ex.: arroz, ovos, tomate..."
              class="chat-input pantry-name"
            />

            <div class="pantry-fields">
              <input type="text" name="qty" value={@qty} maxlength="4" inputmode="decimal" pattern="[0-9]*" oninput="this.value=this.value.replace(/[^0-9.,]/g,'').slice(0,4)" placeholder="Qtd." class="pantry-qty" />
              <select name="unit" class="pantry-select pantry-unit">
                <%= for u <- @units do %>
                  <option value={u} selected={@unit == u}><%= u %></option>
                <% end %>
              </select>
              <select name="category" class="pantry-select pantry-cat">
                <%= for category <- @categories do %>
                  <option value={category} selected={@category == category}><%= category %></option>
                <% end %>
              </select>
            </div>

            <button type="submit" class="send-btn pantry-add-btn" aria-label="Adicionar item" disabled={@adding or @name == "" or @qty == ""}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            </button>
          </form>

          <div class="pantry-count">Itens (<%= length(@items) %>)</div>

          <%= if @items == [] do %>
            <div class="pantry-empty">Sua despensa esta vazia. Adicione o primeiro item acima.</div>
          <% else %>
            <div class="pantry-list">
              <%= for item <- @items do %>
                <div class="pantry-item screen-card">
                  <span class="p-name"><%= item["name"] %></span>
                  <span class="p-qty"><%= item["quantity"] %> <%= item["unit"] %></span>
                  <span class="p-cat"><%= item["category"] %></span>
                  <button phx-click="open_edit" phx-value-id={item["id"]} class="p-edit" aria-label="Editar item">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"></path><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z"></path></svg>
                  </button>
                  <button phx-click="delete_item" phx-value-id={item["id"]} class="p-remove" aria-label="Remover item">✕</button>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @edit_open do %>
            <div class="pantry-modal screen-card">
              <div class="pantry-modal-header">
                <div class="row-title">Editar item</div>
                <button type="button" class="icon-btn" phx-click="close_edit" aria-label="Fechar">✕</button>
              </div>

              <form phx-submit="save_edit" phx-change="update_edit_form" class="pantry-form pantry-edit-form">
                <input type="text" name="name" value={@edit_name} maxlength="30" placeholder="Ex.: arroz, ovos, tomate..." class="chat-input pantry-name" />

                <div class="pantry-fields">
                  <input type="text" name="qty" value={@edit_qty} maxlength="4" inputmode="decimal" pattern="[0-9]*" oninput="this.value=this.value.replace(/[^0-9.,]/g,'').slice(0,4)" placeholder="Qtd." class="pantry-qty" />
                  <select name="unit" class="pantry-select pantry-unit">
                    <%= for u <- @units do %>
                      <option value={u} selected={@edit_unit == u}><%= u %></option>
                    <% end %>
                  </select>
                  <select name="category" class="pantry-select pantry-cat">
                    <%= for category <- @categories do %>
                      <option value={category} selected={@edit_category == category}><%= category %></option>
                    <% end %>
                  </select>
                </div>

                <button type="submit" class="pantry-save-btn" disabled={@saving_edit or @edit_name == "" or @edit_qty == ""}>Salvar alteracoes</button>
              </form>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
