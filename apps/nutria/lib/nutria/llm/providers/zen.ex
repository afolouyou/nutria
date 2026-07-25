defmodule Nutria.LLM.Providers.Zen do
  @moduledoc """
  OpenCode Zen provider (OpenAI-compatible API).
  Supports streaming via SSE with stream: true.
  """
  @behaviour Nutria.LLM.Provider

  require Logger

  @base_url "https://opencode.ai/zen"

  @impl true
  def chat(messages, opts \\ []) do
    _model = opts[:model] || default_model()
    api_key = opts[:api_key] || default_api_key()
    system_prompt = opts[:system_prompt]
    temperature = opts[:temperature] || 0.7

    request = build_request(messages, system_prompt, temperature, false)

    url = "#{@base_url}/v1/chat/completions"

    case Req.post(url, json: request, headers: auth_headers(api_key), receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.error("[Zen] Unexpected response: #{inspect(body)}")
        {:error, :llm_error, "Resposta inválida da IA"}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[Zen] Error #{status}: #{inspect(body)}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("[Zen] Request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  @impl true
  def chat_stream(messages, caller_pid, opts \\ []) do
    _model = opts[:model] || default_model()
    api_key = opts[:api_key] || default_api_key()
    system_prompt = opts[:system_prompt]
    temperature = opts[:temperature] || 0.7

    request = build_request(messages, system_prompt, temperature, true)

    url = "#{@base_url}/v1/chat/completions"

    case Req.post(url, json: request, headers: auth_headers(api_key), into: :self, receive_timeout: 120_000) do
      {:ok, %Req.Response{status: 200, body: stream}} ->
        parse_sse_stream(stream, caller_pid)
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[Zen] Stream error #{status}: #{inspect(body)}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("[Zen] Stream request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  defp build_request(messages, system_prompt, temperature, stream?) do
    msgs =
      if system_prompt do
        [%{"role" => "system", "content" => system_prompt} | messages]
      else
        messages
      end

    base = %{
      "model" => default_model(),
      "messages" => msgs,
      "temperature" => temperature
    }

    if stream? do
      Map.put(base, "stream", true)
    else
      base
    end
  end

  defp parse_sse_stream(stream, caller_pid) do
    stream
    |> Enum.reduce(<<>>, fn chunk, buffer ->
      buffer = buffer <> chunk
      {events, rest} = split_sse_events(buffer)
      process_zen_events(events, caller_pid)
      rest
    end)
    |> then(fn rest ->
      if rest != <<>>, do: process_zen_events([rest], caller_pid)
    end)

    send(caller_pid, {:stream_done, ""})
  end

  defp split_sse_events(data) do
    case String.split(data, "\n\n") do
      [_] -> {[], data}
      parts ->
        {events, [last]} = Enum.split(parts, -1)
        {events, last}
    end
  end

  defp process_zen_events(events, caller_pid) do
    Enum.each(events, fn event ->
      String.split(event, "\n")
      |> Enum.each(fn
        "data: " <> json ->
          json = String.trim(json)

          if json != "[DONE]" && json != "" do
            case Jason.decode(json) do
              {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}} ->
                if content do
                  send(caller_pid, {:chunk, content})
                end

              _ ->
                :ok
            end
          end

        _ ->
          :ok
      end)
    end)
  end

  defp auth_headers(api_key) do
    [{"authorization", "Bearer #{api_key}"}]
  end

  defp default_api_key do
    Application.get_env(:nutria, :llm)[:zen_api_key]
  end

  defp default_model do
    Application.get_env(:nutria, :llm)[:smart_model] || "deepseek-v4-flash-free"
  end
end
