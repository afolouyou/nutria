defmodule Nutria.LLM.Providers.Google do
  @moduledoc """
  Google AI Studio (Generative Language API) provider.
  Supports streaming via streamGenerateContent with alt=sse.
  """
  @behaviour Nutria.LLM.Provider

  require Logger

  @base_url "https://generativelanguage.googleapis.com/v1beta"

  @impl true
  def chat(messages, opts \\ []) do
    model = opts[:model] || default_model()
    api_key = opts[:api_key] || default_api_key()
    system_prompt = opts[:system_prompt]
    temperature = opts[:temperature] || 0.7

    request = build_request(messages, system_prompt, temperature, false)

    url = "#{@base_url}/models/#{model}:generateContent"

    case Req.post(url, json: request, headers: [{"x-goog-api-key", api_key}], receive_timeout: 60_000) do
      {:ok, %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => parts}} | _]}}} ->
        text = parts |> Enum.map(& &1["text"]) |> Enum.join("")
        {:ok, text}

      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.error("[Google] Unexpected response: #{inspect(body)}")
        {:error, :llm_error, "Resposta inválida da IA"}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[Google] Error #{status}: #{inspect(body)}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("[Google] Request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  @impl true
  def chat_stream(messages, caller_pid, opts \\ []) do
    model = opts[:model] || default_model()
    api_key = opts[:api_key] || default_api_key()
    system_prompt = opts[:system_prompt]
    temperature = opts[:temperature] || 0.7

    request = build_request(messages, system_prompt, temperature, true)
    url = "#{@base_url}/models/#{model}:streamGenerateContent?alt=sse"

    case Req.post(url, json: request, headers: [{"x-goog-api-key", api_key}], into: :self, receive_timeout: 120_000) do
      {:ok, %Req.Response{status: 200, body: stream}} ->
        parse_sse_stream(stream, caller_pid, :google)
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[Google] Stream error #{status}: #{inspect(body)}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("[Google] Stream request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  defp build_request(messages, system_prompt, temperature, stream?) do
    contents =
      Enum.map(messages, fn msg ->
        %{
          "role" => if(msg["role"] == "assistant", do: "model", else: msg["role"]),
          "parts" => [%{"text" => msg["content"]}]
        }
      end)

    base = %{
      "contents" => contents,
      "generationConfig" => %{"temperature" => temperature}
    }

    base =
      if system_prompt do
        Map.put(base, "system_instruction", %{"parts" => [%{"text" => system_prompt}]})
      else
        base
      end

    if stream? do
      base
    else
      base
    end
  end

  defp parse_sse_stream(stream, caller_pid, _provider) do
    stream
    |> Enum.reduce(<<>>, fn chunk, buffer ->
      buffer = buffer <> chunk
      {events, rest} = split_sse_events(buffer)
      process_google_events(events, caller_pid)
      rest
    end)
    |> then(fn rest ->
      if rest != <<>>, do: process_google_events([rest], caller_pid)
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

  defp process_google_events(events, caller_pid) do
    Enum.each(events, fn event ->
      String.split(event, "\n")
      |> Enum.each(fn
        "data: " <> json ->
          json = String.trim(json)

          if json != "" do
            case Jason.decode(json) do
              {:ok, %{"candidates" => [%{"content" => %{"parts" => parts}} | _]}} ->
                text = parts |> Enum.map(& &1["text"]) |> Enum.join("")
                if text != "", do: send(caller_pid, {:chunk, text})

              _ ->
                :ok
            end
          end

        _ ->
          :ok
      end)
    end)
  end

  defp default_api_key do
    Application.get_env(:nutria, :llm)[:google_api_key]
  end

  defp default_model do
    Application.get_env(:nutria, :llm)[:fast_model] || "gemma-4-31b-it"
  end
end
