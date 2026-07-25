defmodule NutriaWeb.ChatLive.Index do
  @moduledoc """
  Main chat interface with message streaming.
  """
  use NutriaWeb, :live_view

  on_mount {NutriaWeb.Live.AuthHelpers, :require_user}

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
     |> assign(:suggestions, @suggestions)}
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

        task =
          Task.async(fn ->
            send_message_and_stream(user.id, text, conv_id, self())
          end)

        {:noreply,
         socket
         |> assign(:sending, true)
         |> assign(:streaming_text, "")
         |> assign(:streaming_task, task)
         |> assign(:new_conv_id, nil)}
      else
        {:noreply, redirect(socket, to: ~p"/login")}
      end
    end
  end

  def handle_event("suggestion_click", %{"text" => text}, socket) do
    handle_event("send_message", %{"text" => text}, socket)
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
    {:noreply, update(socket, :streaming_text, &(&1 <> text))}
  end

  def handle_info({:stream_done, full_text}, socket) do
    user = socket.assigns.current_user
    conv_id = socket.assigns[:new_conv_id] || socket.assigns.current_conversation_id

    # Save the complete assistant message to DB
    {:ok, _msg} = Conversations.add_message(conv_id, "assistant", full_text)

    conversations = if user, do: refresh_conversations(user.id), else: socket.assigns.conversations

    {:noreply,
     socket
     |> assign(:sending, false)
     |> assign(:streaming_text, "")
     |> assign(:current_conversation_id, conv_id)
     |> assign(:messages, socket.assigns.messages ++ [%{"id" => Ecto.UUID.generate(), "role" => "assistant", "text" => full_text, "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()}])
     |> assign(:conversations, conversations)}
  end

  def handle_info({:msg_saved, conv_id, user_msg}, socket) do
    {:noreply,
     socket
     |> assign(:current_conversation_id, conv_id)
     |> assign(:messages, socket.assigns.messages ++ [user_msg])}
  end

  def handle_info({ref, {:error, message}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(:sending, false)
     |> assign(:streaming_text, "")
     |> put_flash(:error, message)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  defp send_message_and_stream(user_id, text, conv_id, parent_pid) do
    # Get or create conversation
    conv_id =
      if conv_id && conv_id != "" do
        case Nutria.Repo.get(Nutria.Conversations.Conversation, conv_id) do
          %{user_id: ^user_id} -> conv_id
          _ -> nil
        end
      end

    conv_id =
      cond do
        conv_id -> conv_id
        true ->
          title = if String.length(text) > 50, do: String.slice(text, 0, 50) <> "...", else: text
          {:ok, conv} = Conversations.create_conversation(user_id, title)
          conv.id
      end

    # Save user message
    {:ok, user_msg} = Conversations.add_message(conv_id, "user", text)
    user_msg_map = %{
      "id" => user_msg.id,
      "role" => "user",
      "text" => user_msg.text,
      "created_at" => DateTime.from_naive!(user_msg.inserted_at, "Etc/UTC") |> DateTime.to_iso8601()
    }
    send(parent_pid, {:msg_saved, conv_id, user_msg_map})

    # Get prior messages for context
    prior = Conversations.get_prior_messages(conv_id, user_msg.id)

    # Stream response from Gemini
    config = Application.get_env(:nutria, :gemini)
    api_key = config[:api_key]
    model = config[:model] || "gemini-3-flash-preview"

    messages = build_chat_messages(text, prior)

    request = %{
      contents: messages,
      system_instruction: %{parts: [%{text: system_prompt()}]},
      generation_config: %{temperature: 0.7}
    }

    url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:streamGenerateContent?alt=sse"

    case stream_gemini(url, api_key, request, parent_pid) do
      {:ok, full_text} ->
        send(parent_pid, {:stream_done, full_text})
        Conversations.update_conversation_timestamp(conv_id)

      {:error, reason} ->
        send(parent_pid, {make_ref(), {:error, reason}})
    end
  end

  defp stream_gemini(url, api_key, request, _parent_pid) do
    # Use a simple approach: make the request and parse response
    case Req.post(url, json: request, headers: [{"x-goog-api-key", api_key}]) do
      {:ok, %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => parts}} | _]}}} ->
        full_text = parts |> Enum.map(& &1["text"]) |> Enum.join("")
        {:ok, full_text}

      {:ok, %Req.Response{status: 200, body: _body}} ->
        {:error, "Resposta inválida da IA"}

      {:ok, %Req.Response{status: status}} ->
        {:error, "Erro ao consultar IA (#{status})"}

      {:error, _reason} ->
        {:error, "Erro de conexão com IA"}
    end
  end

  defp build_chat_messages(text, prior_messages) do
    prior =
      prior_messages
      |> Enum.map(fn msg ->
        prefix = if msg.role == "user", do: "Usuário", else: "NutrIA"
        "#{prefix}: #{msg.text}"
      end)

    combined =
      if prior != [] do
        history = Enum.join(prior, "\n")
        "Histórico da conversa:\n#{history}\nNova mensagem do usuário: #{text}"
      else
        text
      end

    [%{role: "user", parts: [%{text: combined}]}]
  end

  defp system_prompt do
    "Você é o NutrIA, um assistente nutricional simpático, motivador e especialista em nutrição saudável. Responda sempre em português brasileiro de forma clara e objetiva. Você ajuda os usuários com: análise nutricional de refeições, dicas de alimentação saudável, criação de planos alimentares personalizados e sugestões para o dia a dia. Use emojis com moderação para tornar as respostas amigáveis. Quando relevante, organize a resposta em tópicos."
  end

  defp refresh_conversations(user_id) do
    Conversations.list_conversations(user_id)
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
          <div class="input-wrapper">
            <form phx-submit="send_message">
              <input
                type="text"
                name="text"
                class="chat-input"
                placeholder="Pergunte ao NutrIA..."
                disabled={@sending}
                autocomplete="off"
              />
            </form>
          </div>
        </div>
      <% else %>
        <div class="messages-container" id="messages-container" phx-hook="ScrollBottom">
          <div class="messages-list">
            <%= for msg <- @messages do %>
              <div class={["message", msg["role"]]}>
                <div class="message-bubble">
                  <%= msg["text"] %>
                </div>
              </div>
            <% end %>

            <%= if @streaming_text != "" do %>
              <div class="message assistant">
                <div class="message-bubble streaming-cursor">
                  <%= @streaming_text %>
                </div>
              </div>
            <% end %>

            <%= if @sending and @streaming_text == "" do %>
              <div class="message assistant">
                <div class="loading-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="input-area">
          <div class="input-wrapper">
            <form phx-submit="send_message">
              <input
                type="text"
                name="text"
                class="chat-input"
                placeholder="Pergunte ao NutrIA..."
                disabled={@sending}
                autocomplete="off"
              />
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
