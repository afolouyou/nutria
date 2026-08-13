defmodule NutriaWeb.ChatLive.Index do
  @moduledoc """
  Main chat interface with multi-provider streaming.
  """
  use NutriaWeb, :live_view

  on_mount({NutriaWeb.Live.AuthHelpers, :require_user})

  import NutriaWeb.CoreComponents

  alias Nutria.Conversations

  @suggestions [
    "Analise meu almoço: arroz, feijão, frango grelhado e salada",
    "Crie um plano alimentar para emagrecer 3kg",
    "Dicas para reduzir açúcar no dia a dia",
    "O que devo comer no café da manhã?"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:current_conversation_id, nil)
     |> assign(:sending, false)
     |> assign(:streaming_text, "")
     |> assign(:streaming_buffer, "")
     |> assign(:stream_complete, false)
     |> assign(:thinking_title, "")
     |> assign(:suggestions, @suggestions)
     |> assign(:llm_mode, :fast)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    if user do
      case Conversations.get_conversation(id, user.id) do
        {:ok, conv} ->
          messages = conv["messages"] || []

          {:noreply,
           socket
           |> assign(:current_conversation_id, id)
           |> assign(:messages, messages)
           |> assign(:conversations, refresh_conversations(user.id))}

        {:error, _, _} ->
          {:noreply, redirect(socket, to: ~p"/chat")}
      end
    else
      {:noreply, redirect(socket, to: ~p"/login")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:current_conversation_id, nil)
     |> assign(:messages, [])}
  end

  @impl true
  def handle_event("send_message", %{"text" => _text}, %{assigns: %{sending: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"text" => text}, socket) do
    text = text |> to_string() |> String.trim()

    if text == "" do
      {:noreply, socket}
    else
      user = socket.assigns.current_user

      if user do
        conv_id = socket.assigns.current_conversation_id
        mode = socket.assigns.llm_mode
        lv_pid = self()

        main_task =
          Task.async(fn ->
            send_message_and_stream(user.id, text, conv_id, mode, lv_pid)
          end)

        user_msg = %{
          "id" => Ecto.UUID.generate(),
          "role" => "user",
          "text" => text,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }

        {:noreply,
         socket
         |> assign(:sending, true)
         |> assign(:streaming_text, "")
         |> assign(:streaming_buffer, "")
         |> assign(:stream_complete, false)
         |> assign(:thinking_title, "")
         |> assign(:streaming_task, main_task)
         |> assign(:new_conv_id, nil)
         |> update(:messages, &(&1 ++ [user_msg]))}
      else
        {:noreply, redirect(socket, to: ~p"/login")}
      end
    end
  end

  def handle_event("suggestion_click", %{"text" => text}, socket) do
    handle_event("send_message", %{"text" => text}, socket)
  end

  def handle_event("toggle_mode", _params, socket) do
    new_mode = if socket.assigns.llm_mode == :fast, do: :smart, else: :fast
    {:noreply, assign(socket, :llm_mode, new_mode)}
  end

  def handle_event("new_chat", _params, socket) do
    user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:current_conversation_id, nil)
     |> assign(:messages, [])
     |> assign(:conversations, if(user, do: refresh_conversations(user.id), else: []))
     |> push_navigate(to: ~p"/chat")}
  end

  @impl true
  def handle_info({:chunk, text}, socket) do
    socket =
      if palavra_colada?(socket.assigns.streaming_buffer, text) do
        update(socket, :streaming_buffer, &(&1 <> " " <> text))
      else
        update(socket, :streaming_buffer, &(&1 <> text))
      end

    socket = assign(socket, :thinking_title, "")
    Process.send_after(self(), :stream_tick, 5)
    {:noreply, socket}
  end

  def handle_info({:thinking_title, title}, socket) do
    if socket.assigns.streaming_text == "" and socket.assigns.thinking_title == "" do
      {:noreply, assign(socket, :thinking_title, title)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:stream_tick, socket) do
    case socket.assigns.streaming_buffer do
      "" ->
        if socket.assigns.stream_complete do
          finalize_stream(socket)
        else
          {:noreply, socket}
        end

      buffer ->
        {char, rest} = String.split_at(buffer, 1)
        Process.send_after(self(), :stream_tick, 5)

        {:noreply,
         socket
         |> assign(:streaming_buffer, rest)
         |> assign(:streaming_text, socket.assigns.streaming_text <> char)}
    end
  end

  def handle_info({:stream_done, _full_text}, socket) do
    socket = assign(socket, :stream_complete, true)
    Process.send_after(self(), :stream_tick, 5)
    {:noreply, socket}
  end

  def handle_info({:conv_created, conv_id}, socket) do
    {:noreply, assign(socket, :current_conversation_id, conv_id)}
  end

  def handle_info({:settings_avatar_updated, user, kind, message}, socket) do
    {:noreply,
     socket
     |> assign(:current_user, user)
     |> put_flash(kind, message)}
  end

  def handle_info({ref, {:error, message}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(:sending, false)
     |> assign(:streaming_text, "")
     |> assign(:streaming_buffer, "")
     |> assign(:stream_complete, false)
     |> put_flash(:error, message)}
  end

  def handle_info({ref, _result}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  defp palavra_colada?(buffer, chunk) do
    buffer != "" and
      String.match?(buffer, ~r/[a-zA-ZáéíóúàâêôãõçÁÉÍÓÚÀÂÊÔÃÕÇ]$/) and
      String.match?(chunk, ~r/^[a-zA-ZáéíóúàâêôãõçÁÉÍÓÚÀÂÊÔÃÕÇ]/)
  end

  defp send_message_and_stream(user_id, text, conv_id, mode, lv_pid) do
    conv_id =
      if conv_id && conv_id != "" do
        case Nutria.Repo.get(Nutria.Conversations.Conversation, conv_id) do
          %{user_id: ^user_id} -> conv_id
          _ -> nil
        end
      end

    {conv_id, is_new} =
      cond do
        conv_id ->
          {conv_id, false}

        true ->
          title = if String.length(text) > 50, do: String.slice(text, 0, 50) <> "...", else: text
          {:ok, conv} = Conversations.create_conversation(user_id, title)
          {conv.id, true}
      end

    if is_new, do: send(lv_pid, {:conv_created, conv_id})

    {:ok, user_msg} = Conversations.add_message(conv_id, "user", text)
    prior = Conversations.get_prior_messages(conv_id, user_msg.id)

    case Nutria.LLM.chat_stream(text, prior, lv_pid, mode) do
      :ok -> :ok
      {:error, _, reason} -> send(lv_pid, {make_ref(), {:error, reason}})
    end
  end

  defp refresh_conversations(user_id) do
    Conversations.list_conversations(user_id)
  end

  defp finalize_stream(socket) do
    full_text = socket.assigns.streaming_text

    if full_text != "" do
      conv_id = socket.assigns.current_conversation_id
      {:ok, _msg} = Conversations.add_message(conv_id, "assistant", full_text)
    end

    user = socket.assigns.current_user

    conversations =
      if user, do: refresh_conversations(user.id), else: socket.assigns.conversations

    if full_text == "" do
      {:noreply,
       socket
       |> assign(:sending, false)
       |> assign(:streaming_text, "")
       |> assign(:streaming_buffer, "")
       |> assign(:stream_complete, false)
       |> assign(:thinking_title, "")}
    else
      {:noreply,
       socket
       |> assign(:sending, false)
       |> assign(:streaming_text, "")
       |> assign(:streaming_buffer, "")
       |> assign(:stream_complete, false)
       |> assign(:thinking_title, "")
       |> assign(
         :messages,
         socket.assigns.messages ++
           [
             %{
               "id" => Ecto.UUID.generate(),
               "role" => "assistant",
               "text" => full_text,
               "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
             }
           ]
       )
       |> assign(:conversations, conversations)}
    end
  end

  defp render_markdown(text) do
    text
    |> escape_html()
    |> bold()
    |> format_paragraphs()
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp bold(text) do
    Regex.replace(~r/\*\*(.+?)\*\*/, text, "<strong>\\1</strong>")
  end

  defp format_paragraphs(text) do
    text
    |> String.split("\n\n")
    |> Enum.map(&format_block/1)
    |> Enum.join("")
  end

  defp format_block(block) do
    lines = String.split(block, "\n")

    cond do
      Enum.any?(lines, &String.match?(&1, ~r/^[-*] /)) ->
        items =
          lines
          |> Enum.filter(&String.match?(&1, ~r/^[-*] /))
          |> Enum.map(fn line -> "<li>#{String.trim_leading(line, "- ")}</li>" end)
          |> Enum.join("")

        "<ul>#{items}</ul>"

      Enum.any?(lines, &String.match?(&1, ~r/^\d+\. /)) ->
        items =
          lines
          |> Enum.filter(&String.match?(&1, ~r/^\d+\. /))
          |> Enum.map(fn line ->
            text = String.replace(line, ~r/^\d+\. /, "")
            "<li>#{text}</li>"
          end)
          |> Enum.join("")

        "<ul>#{items}</ul>"

      true ->
        body = Enum.join(lines, "<br>")
        "<p>#{body}</p>"
    end
  end

  defp render_streaming(text) do
    text
    |> escape_html()
    |> streaming_bold()
    |> streaming_paragraphs()
  end

  defp streaming_bold(text) do
    parts = String.split(text, "**")

    case length(parts) do
      1 ->
        hd(parts)

      n when rem(n, 2) == 1 ->
        parts
        |> Enum.chunk_every(2)
        |> Enum.map(fn
          [plain, bold] -> plain <> "<strong>" <> bold <> "</strong>"
          [plain] -> plain
        end)
        |> Enum.join("")

      n when rem(n, 2) == 0 ->
        {complete, [open]} = Enum.split(parts, -1)

        rendered =
          complete
          |> Enum.chunk_every(2)
          |> Enum.map(fn
            [plain, bold] -> plain <> "<strong>" <> bold <> "</strong>"
            [plain] -> plain
          end)
          |> Enum.join("")

        rendered <> "<strong>" <> open <> "</strong>"
    end
  end

  defp streaming_paragraphs(text) do
    text
    |> String.split("\n\n")
    |> Enum.map(fn block ->
      body = String.replace(block, "\n", "<br>")
      "<p>#{body}</p>"
    end)
    |> Enum.join("")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-direction:column;height:100%">
      <header class="chat-header">
        Chat
      </header>

      <%= if @messages == [] and @streaming_text == "" do %>
        <div class="chat-body">
          <h1 class="welcome-title">Olá! Eu sou o NutrIA.</h1>
          <p class="welcome-subtitle">
            Pergunte sobre nutrição, peça análises de refeições, dicas ou planos alimentares.
          </p>

          <div class="suggestions-grid">
            <%= for suggestion <- @suggestions do %>
              <.suggestion_card text={suggestion} phx_click="suggestion_click" />
            <% end %>
          </div>
        </div>

        <div class="input-area">
          <div class="mode-toggle-bar">
            <button
              type="button"
              class={["mode-btn", @llm_mode == :fast && "active"]}
              phx-click="toggle_mode"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
              Basic
            </button>
            <button
              type="button"
              class={["mode-btn", @llm_mode == :smart && "active"]}
              phx-click="toggle_mode"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2a7 7 0 0 1 7 7c0 3-2 5.5-4 7.5L12 20l-3-3.5C7 14.5 5 12 5 9a7 7 0 0 1 7-7z"/><path d="M9 9h.01M15 9h.01M9.5 13a3.5 3.5 0 0 0 5 0"/></svg>
              Esperto
            </button>
          </div>
          <div class="input-wrapper">
            <form phx-submit="send_message" class="chat-form">
              <input
                type="text"
                name="text"
                class="chat-input"
                placeholder="Pergunte ao NutrIA..."
                disabled={@sending}
                autocomplete="off"
              />
              <button
                type="submit"
                class="send-btn"
                disabled={@sending}
                aria-label="Enviar"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg>
              </button>
            </form>
          </div>
        </div>
      <% else %>
        <div class="messages-container" id="messages-container" phx-hook="ScrollBottom">
          <div class="messages-list">
            <%= for msg <- @messages do %>
              <div class={["message", msg["role"]]}>
                <div class="message-bubble">
                  <%= if msg["role"] == "assistant" do %>
                    <%= raw(render_markdown(msg["text"])) %>
                  <% else %>
                    <%= msg["text"] %>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= if @streaming_text != "" do %>
              <div class="message assistant">
                <div class="message-bubble streaming-cursor">
                  <%= raw(render_streaming(@streaming_text)) %>
                </div>
              </div>
            <% end %>

            <%= if @sending and @streaming_text == "" do %>
              <div class="message assistant">
              <%= if @thinking_title != "" do %>
                <div class="thinking-badge">
                  <span class="thinking-icon">💭</span>
                  Pensando: <%= @thinking_title %>
                </div>
              <% else %>
                <div class="loading-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <div class="input-area">
          <div class="mode-toggle-bar">
            <button
              type="button"
              class={["mode-btn", @llm_mode == :fast && "active"]}
              phx-click="toggle_mode"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
              Basic
            </button>
            <button
              type="button"
              class={["mode-btn", @llm_mode == :smart && "active"]}
              phx-click="toggle_mode"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2a7 7 0 0 1 7 7c0 3-2 5.5-4 7.5L12 20l-3-3.5C7 14.5 5 12 5 9a7 7 0 0 1 7-7z"/><path d="M9 9h.01M15 9h.01M9.5 13a3.5 3.5 0 0 0 5 0"/></svg>
              Esperto
            </button>
          </div>
          <div class="input-wrapper">
            <form phx-submit="send_message" class="chat-form">
              <input
                type="text"
                name="text"
                class="chat-input"
                placeholder="Pergunte ao NutrIA..."
                disabled={@sending}
                autocomplete="off"
              />
              <button
                type="submit"
                class="send-btn"
                disabled={@sending}
                aria-label="Enviar"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg>
              </button>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
