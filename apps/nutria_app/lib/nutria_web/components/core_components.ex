defmodule NutriaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for Nutria.
  """
  use Phoenix.Component

  attr(:flash, :map, required: true)
  attr(:kind, :atom, required: true)

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = @flash[@kind]}
      class={[
        "flash-container",
        @kind == :error && "flash-error",
        @kind == :info && "flash-info"
      ]}
      phx-click="lv:clear-flash"
      phx-value-kind={@kind}
      role="alert"
    >
      <%= msg %>
    </div>
    """
  end

  attr(:flash, :map, required: true)

  def flash_group(assigns) do
    ~H"""
    <div>
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global)

  def button(assigns) do
    ~H"""
    <button
      class={[
        "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-colors",
        "bg-[#2d6a4f] text-white hover:bg-[#1b4332]",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global)

  def button_outline(assigns) do
    ~H"""
    <button
      class={[
        "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-colors",
        "bg-white border border-[#dee2e6] text-[#333] hover:bg-[#f0f0f0]",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)
  attr(:rest, :global)

  def button_accent(assigns) do
    ~H"""
    <button
      class={[
        "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-colors",
        "bg-[#fc7100] text-white hover:bg-[#e06500]",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr(:label, :string, required: true)
  attr(:field, Phoenix.HTML.FormField)
  attr(:type, :string, default: "text")
  attr(:placeholder, :string, default: nil)
  attr(:rest, :global, include: ~w(autocomplete disabled readonly value min max step))

  def input(assigns) do
    ~H"""
    <div class="w-full">
      <label :if={@label} class="block text-sm font-medium text-[#333] mb-1.5">
        <%= @label %>
      </label>
      <input
        type={@type}
        name={@field && @field.name}
        id={@field && @field.id}
        value={Phoenix.HTML.Form.input_value(@field, nil) || @rest[:value]}
        placeholder={@placeholder}
        class={[
          "w-full px-4 py-3 border border-[#dee2e6] rounded-xl text-[15px] bg-[#f8f9fa] outline-none transition-colors",
          "focus:border-[#2d6a4f] focus:bg-white focus:ring-3 focus:ring-[#2d6a4f]/10",
          "disabled:opacity-50 disabled:cursor-not-allowed",
          @field && @field.errors != [] && "border-red-500"
        ]}
        {@rest}
      />
      <p :if={@field && @field.errors != []} class="mt-1 text-xs text-red-600">
        <%= Enum.at(@field.errors, 0) |> elem(1) |> elem(0) %>
      </p>
    </div>
    """
  end

  slot(:inner_block, required: true)
  attr(:rest, :global)

  def card(assigns) do
    ~H"""
    <div class="bg-white border border-[#dee2e6] rounded-xl p-4" {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:class, :string, default: nil)

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
      @class
    ]}>
      <%= @label %>
    </span>
    """
  end

  attr(:text, :string, required: true)
  attr(:phx_click, :string, default: nil)

  def suggestion_card(assigns) do
    ~H"""
    <div
      class="suggestion-card"
      phx-click={@phx_click}
      phx-value-text={@text}
    >
      <%= @text %>
    </div>
    """
  end

  slot(:inner_block, required: true)
  attr(:class, :string, default: nil)

  def page_header(assigns) do
    ~H"""
    <header class={[
      "px-6 py-4 border-b border-[#e9ecef] font-semibold text-base",
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </header>
    """
  end
end
