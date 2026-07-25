defmodule Nutria.LLM.Gemini do
  @moduledoc """
  Wrapper for Gemini LLM interactions via REST API.
  """
  require Logger

  @system_prompt "Você é o NutrIA, um assistente nutricional simpático, motivador e especialista em nutrição saudável. Responda sempre em português brasileiro de forma clara e objetiva. Você ajuda os usuários com: análise nutricional de refeições, dicas de alimentação saudável, criação de planos alimentares personalizados e sugestões para o dia a dia. Use emojis com moderação para tornar as respostas amigáveis. Quando relevante, organize a resposta em tópicos."

  @recipe_prompt "Você é o NutrIA, um chef nutricional. Dado uma lista de ingredientes que o usuário possui na despensa, sugira 2 a 3 receitas saudáveis, criativas e práticas usando preferencialmente apenas esses ingredientes (você pode sugerir temperos básicos comuns como sal, óleo, azeite). Para cada receita inclua: nome, breve descrição, lista de ingredientes (com quantidades), modo de preparo passo a passo, e benefício nutricional principal. Responda em português brasileiro, formatando com markdown leve (negrito e listas)."

  def chat(text, prior_messages \\ []) do
    config = Application.get_env(:nutria, :gemini)
    api_key = config[:api_key]
    model = config[:model] || "gemini-3-flash-preview"

    messages = build_chat_messages(text, prior_messages)

    request = %{
      contents: messages,
      system_instruction: %{parts: [%{text: @system_prompt}]},
      generation_config: %{temperature: 0.7}
    }

    url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent"

    case Req.post(url, json: request, headers: [{"x-goog-api-key", api_key}]) do
      {:ok, %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => parts}} | _]}}} ->
        text = parts |> Enum.map(& &1["text"]) |> Enum.join("")
        {:ok, text}

      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.error("Gemini unexpected response: #{inspect(body)}")
        {:error, :llm_error, "Resposta inválida da IA"}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Gemini error #{status}: #{inspect(body)}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("Gemini request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  def recipe(inventory_text, notes \\ nil) do
    config = Application.get_env(:nutria, :gemini)
    api_key = config[:api_key]
    model = config[:model] || "gemini-3-flash-preview"

    prompt = """
    Itens disponíveis na despensa do usuário:
    #{inventory_text}

    Sugira UMA receita prática e saudável usando esses ingredientes.
    Inclua: nome, ingredientes com quantidades exatas, modo de preparo, benefício nutricional.

    IMPORTANTE: Ao final, inclua um bloco JSON delimitado por <USAGE>...</USAGE> listando o que foi consumido,
    no formato exato: <USAGE>[{"name":"arroz","quantity":0.4,"unit":"kg"}]</USAGE>.
    Use os mesmos nomes (case-insensitive) e unidades dos itens da despensa.
    Não consuma mais do que está disponível.
    """

    prompt =
      if notes && String.trim(notes) != "" do
        prompt <> "\nObservações: #{notes}"
      else
        prompt
      end

    messages = [%{role: "user", parts: [%{text: prompt}]}]

    request = %{
      contents: messages,
      system_instruction: %{parts: [%{text: @recipe_prompt}]},
      generation_config: %{temperature: 0.8}
    }

    url = "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent"

    case Req.post(url, json: request, headers: [{"x-goog-api-key", api_key}]) do
      {:ok, %Req.Response{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => parts}} | _]}}} ->
        raw_text = parts |> Enum.map(& &1["text"]) |> Enum.join("")
        {:ok, raw_text}

      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.error("Gemini recipe unexpected: #{inspect(body)}")
        {:error, :llm_error, "Resposta inválida da IA"}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Gemini recipe error #{status}: #{inspect(body)}")
        {:error, :llm_error, "Erro ao consultar IA (#{status})"}

      {:error, reason} ->
        Logger.error("Gemini recipe request error: #{inspect(reason)}")
        {:error, :llm_error, "Erro de conexão com IA"}
    end
  end

  defp build_chat_messages(text, prior_messages) do
    prior_msgs =
      prior_messages
      |> Enum.map(fn msg ->
        prefix = if msg.role == "user", do: "Usuário", else: "NutrIA"
        "#{prefix}: #{msg.text}"
      end)

    combined =
      if prior_msgs != [] do
        history_text = Enum.join(prior_msgs, "\n")
        "Histórico da conversa:\n#{history_text}\nNova mensagem do usuário: #{text}"
      else
        text
      end

    [%{role: "user", parts: [%{text: combined}]}]
  end
end
