defmodule Nutria.LLM.Providers.DeepSeek do
  @moduledoc """
  DeepSeek provider (OpenAI-compatible API at api.deepseek.com).
  Uses Finch for true HTTP streaming of SSE.
  """
  @behaviour Nutria.LLM.Provider

  require Logger

  @host "api.deepseek.com"
  @base_url "https://#{@host}"
  @receive_timeout_ms 120_000

  @impl true
  def chat(messages, opts \\ []) do
    model = opts[:model] || default_model()
    api_key = opts[:api_key] || default_api_key()
    system_prompt = opts[:system_prompt]
    temperature = opts[:temperature] || 0.7

    request = build_request(messages, model, system_prompt, temperature, false)
    url = "#{@base_url}/v1/chat/completions"

    req =
      Finch.build(:post, url, [
        {"content-type", "application/json"},
        {"authorization", "Bearer #{api_key}"}
      ], Jason.encode!(request))

    case Finch.request(req, Nutria.Finch, receive_timeout: @receive_timeout_ms) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
            {:ok, content}

          {:ok, other} ->
            Logger.error("[DeepSeek] Unexpected: #{inspect(other)}")
            {:error, :llm_error, "Resposta inválida da IA"}

          {:error, e} ->
            Logger.error("[DeepSeek] JSON error: #{inspect(e)}")
            {:error, :llm_error, "Resposta inválida da IA"}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("[DeepSeek] Error #{status}: #{body}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("[DeepSeek] Request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  @impl true
  def chat_stream(messages, caller_pid, opts \\ []) do
    model = opts[:model] || default_model()
    api_key = opts[:api_key] || default_api_key()
    system_prompt = opts[:system_prompt]
    temperature = opts[:temperature] || 0.7

    request = build_request(messages, model, system_prompt, temperature, true)
    body_json = Jason.encode!(request)

    spawn(fn ->
      Process.delete(:deepseek_title_sent)
      do_stream(api_key, body_json, caller_pid)
    end)

    :ok
  end

  defp do_stream(api_key, body_json, caller_pid) do
    url = "#{@base_url}/v1/chat/completions"

    req =
      Finch.build(:post, url, [
        {"content-type", "application/json"},
        {"authorization", "Bearer #{api_key}"}
      ], body_json)

    case Finch.stream(req, Nutria.Finch, <<>>, fn
      {:status, status, _headers}, acc ->
        Process.put(:deepseek_http_status, status)
        acc

      {:data, chunk}, acc ->
        new_acc = acc <> chunk
        {events, rest} = split_sse_events(new_acc)
        process_events(events, caller_pid)
        rest

      _other, acc ->
        acc
    end, receive_timeout: @receive_timeout_ms) do
      {:ok, final_buffer} ->
        if final_buffer != <<>> do
          {events, rest} = split_sse_events(final_buffer)
          process_events(events, caller_pid)
          if rest != <<>>, do: process_events([rest], caller_pid)
        end

        case Process.get(:deepseek_http_status) do
          status when is_integer(status) and status >= 400 ->
            Logger.error("[DeepSeek] Non-200 stream status: #{status}")
            send(caller_pid, {:stream_error, friendly_status(status)})

          _ ->
            send(caller_pid, {:stream_done, ""})
        end

      {:error, reason} ->
        Logger.error("[DeepSeek] Stream error: #{inspect(reason)}")
        send(caller_pid, {:stream_error, "Não foi possível conectar à IA. Tente novamente."})
    end
  end

  defp friendly_status(status) do
    cond do
      status in [401, 403] ->
        "A IA recusou a requisição (credencial inválida). Verifique a configuração da chave."

      status == 429 ->
        "O limite de uso da IA foi atingido. Aguarde um instante e tente novamente."

      status >= 500 ->
        "O serviço de IA está indisponível no momento. Tente novamente em instantes."

      true ->
        "Não foi possível concluir a solicitação com a IA. Tente novamente."
    end
  end

  defp split_sse_events(data) do
    case String.split(data, "\n\n") do
      [_] -> {[], data}
      parts ->
        {events, [last]} = Enum.split(parts, -1)
        {events, last}
    end
  end

  defp process_events(events, caller_pid) do
    Enum.each(events, fn event ->
      String.split(event, "\n")
      |> Enum.each(fn
        "data: " <> json ->
          json = String.trim(json)

          if json != "[DONE]" && json != "" do
            case Jason.decode(json) do
              {:ok, %{"choices" => [%{"delta" => delta} | _]}} ->
                cond do
                  content = delta["content"] ->
                    send(caller_pid, {:chunk, content})

                  reasoning = delta["reasoning_content"] ->
                    if not Process.get(:deepseek_title_sent, false) do
                      title =
                        reasoning
                        |> String.trim()
                        |> String.replace(~r/^[-*\s]+/, "")
                        |> String.split(~r/\s+/, parts: 6)
                        |> Enum.take(5)
                        |> Enum.join(" ")

                      if title != "" do
                        send(caller_pid, {:thinking_title, title})
                        Process.put(:deepseek_title_sent, true)
                      end
                    end

                  true -> :ok
                end

              _ -> :ok
            end
          end

        _ -> :ok
      end)
    end)
  end

  defp build_request(messages, model, system_prompt, temperature, stream?) do
    msgs =
      if system_prompt do
        [%{"role" => "system", "content" => system_prompt} | messages]
      else
        messages
      end

    base = %{
      "model" => model,
      "messages" => msgs
    }

    base =
      if String.contains?(model, "reasoner") do
        base
      else
        Map.put(base, "temperature", temperature)
      end

    if stream?, do: Map.put(base, "stream", true), else: base
  end

  defp default_api_key do
    Application.get_env(:nutria, :llm)[:deepseek_api_key]
  end

  defp default_model do
    Application.get_env(:nutria, :llm)[:fast_model] || "deepseek-chat"
  end
end
