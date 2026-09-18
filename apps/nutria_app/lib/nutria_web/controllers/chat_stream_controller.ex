defmodule NutriaWeb.Controllers.ChatStreamController do
  use NutriaWeb, :controller

  def create(conn, %{"text" => text} = params) do
    user_id = conn.assigns.current_user_id
    conversation_id = params["conversation_id"]
    mode = parse_mode(params["mode"])

    text = text |> to_string() |> String.trim()

    if text == "" do
      conn |> put_status(400) |> json(%{"detail" => "Mensagem vazia"})
    else
      plan = plan_of(user_id)

      case Nutria.Chat.ChatUsage.consume(user_id, plan) do
        {:blocked, _} ->
          conn
          |> put_status(429)
          |> json(%{"detail" => "Limite de mensagens do plano Grátis atingido. Assine um plano para continuar."})

        {:ok, chat_remaining} ->
          case prepare_message(user_id, text, conversation_id) do
            {:ok, conv_id, user_msg, prior} ->
              meta = %{plan: Atom.to_string(plan), chat_remaining: chat_remaining}

              conn
              |> put_resp_header("content-type", "text/event-stream")
              |> put_resp_header("cache-control", "no-cache")
              |> put_resp_header("connection", "keep-alive")
              |> send_chunked(200)
              |> stream_response(text, prior, conv_id, user_msg, mode, meta)

            {:error, status, detail} ->
              conn |> put_status(status) |> json(%{"detail" => detail})
          end
      end
    end
  end

  defp plan_of(user_id) do
    case Nutria.Accounts.get_user(user_id) do
      nil -> :free
      user -> Nutria.Plans.plan_of(user)
    end
  end

  defp parse_mode("smart"), do: :smart
  defp parse_mode(_), do: :fast

  defp prepare_message(user_id, text, conv_id) when is_binary(conv_id) and conv_id != "" do
    case Nutria.Repo.get(Nutria.Conversations.Conversation, conv_id) do
      nil ->
        {:error, :not_found, "Conversa não encontrada"}

      conv ->
        if conv.user_id != user_id do
          {:error, :not_found, "Conversa não encontrada"}
        else
          {:ok, user_msg} = Nutria.Conversations.add_message(conv_id, "user", text)
          prior = Nutria.Conversations.get_prior_messages(conv_id, user_msg.id)
          {:ok, conv_id, user_msg, prior}
        end
    end
  end

  defp prepare_message(user_id, text, _conv_id) do
    title =
      if String.length(text) > 50,
        do: String.slice(text, 0, 50) <> "...",
        else: text

    case Nutria.Conversations.create_conversation(user_id, title) do
      {:ok, conv} ->
        {:ok, user_msg} = Nutria.Conversations.add_message(conv.id, "user", text)
        prior = Nutria.Conversations.get_prior_messages(conv.id, user_msg.id)
        {:ok, conv.id, user_msg, prior}

      error ->
        error
    end
  end

defp stream_response(conn, text, prior, conv_id, user_msg, mode, meta) do
    parent = self()

    Task.start(fn ->
      if mode == :smart do
        Nutria.LLM.agent_chat(text, prior, parent, mode)
      else
        Nutria.LLM.chat_stream(text, prior, parent, mode)
      end
    end)

    stream_loop(conn, "", "", conv_id, user_msg, conn.assigns.current_user_id, meta)
  end

  defp stream_loop(conn, raw_acc, visible_pending, conv_id, user_msg, user_id, meta) do
    receive do
      {:thinking_title, title} ->
        send_sse(conn, "thinking", %{"title" => title})
        stream_loop(conn, raw_acc, visible_pending, conv_id, user_msg, user_id, meta)

      {:assistant_note, note} ->
        send_sse(conn, "thinking", %{"title" => note})
        stream_loop(conn, raw_acc, visible_pending, conv_id, user_msg, user_id, meta)

      {:chunk, text} ->
        {visible, pending} = Nutria.Tools.StreamCleaner.stream(visible_pending, text)

        if visible != "" do
          send_sse(conn, "chunk", %{"text" => visible})
        end

        stream_loop(conn, raw_acc <> text, pending, conv_id, user_msg, user_id, meta)

      {:stream_done, _full} ->
        handle_stream_end(conn, raw_acc, conv_id, user_msg, user_id, meta)

      {:stream_error, msg} ->
        send_sse(conn, "error", %{"detail" => msg})
        conn

    after
      90_000 ->
        send_sse(conn, "error", %{"detail" => "O servidor demorou para responder. Tente novamente."})
        conn
    end
  end

  defp handle_stream_end(conn, full_text, conv_id, user_msg, user_id, meta) do
    {_stored_raw, pantry_json} = Nutria.Tools.PantryTool.extract(full_text)
    stored_text = sanitize_visible(full_text)

    if pantry_json do
      case Nutria.Tools.PantryTool.apply(user_id, pantry_json) do
        {:ok, %{"added" => added, "removed" => removed}} ->
          send_sse(conn, "pantry_updated", %{
            "added" => added,
            "removed" => removed
          })

        _ ->
          :ok
      end
    end

    if stored_text != "" do
      case Nutria.Conversations.add_message(conv_id, "assistant", stored_text) do
        {:ok, assistant_msg} ->
          Nutria.Conversations.update_conversation_timestamp(conv_id)

          if pantry_json do
            send_sse(conn, "pantry_done", %{"consumed" => []})
          end

          data = %{
            "conversation_id" => conv_id,
            "plan" => meta.plan,
            "chat_remaining" => meta.chat_remaining,
            "user_message" => %{
              "id" => user_msg.id,
              "role" => "user",
              "text" => user_msg.text,
              "created_at" =>
                DateTime.from_naive!(user_msg.inserted_at, "Etc/UTC") |> DateTime.to_iso8601()
            },
            "assistant_message" => %{
              "id" => assistant_msg.id,
              "role" => "assistant",
              "text" => assistant_msg.text,
              "created_at" =>
                DateTime.from_naive!(assistant_msg.inserted_at, "Etc/UTC")
                |> DateTime.to_iso8601()
            }
          }

          send_sse(conn, "done", data)

        _ ->
          send_sse(conn, "done", %{
            "conversation_id" => conv_id,
            "plan" => meta.plan,
            "chat_remaining" => meta.chat_remaining
          })
      end
    else
      send_sse(conn, "done", %{
        "conversation_id" => conv_id,
        "plan" => meta.plan,
        "chat_remaining" => meta.chat_remaining
      })
    end

    conn
  end

  defp sanitize_visible(raw) do
    {visible, pending} = Nutria.Tools.StreamCleaner.stream("", raw)
    String.trim(visible <> Nutria.Tools.StreamCleaner.finalize(pending))
  end

  defp send_sse(conn, event, data) do
    payload = Jason.encode!(data)
    chunk(conn, "event: #{event}\ndata: #{payload}\n\n")
    conn
  end
end
