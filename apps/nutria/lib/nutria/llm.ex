defmodule Nutria.LLM do
  @moduledoc """
  Multi-provider LLM router.
  Dispatches to the right provider based on mode (fast/smart) with fallback.
  """
  require Logger

  @system_prompt "Você é o NutrIA, um assistente nutricional simpático, motivador e especialista em nutrição saudável. Responda sempre em português brasileiro de forma clara e objetiva. Você ajuda os usuários com: análise nutricional de refeições, dicas de alimentação saudável, criação de planos alimentares personalizados e sugestões para o dia a dia. Use emojis com moderação para tornar as respostas amigáveis. Quando relevante, organize a resposta em tópicos."

  @recipe_prompt "Você é o NutrIA, um chef nutricional. Dado uma lista de ingredientes que o usuário possui na despensa, sugira 2 a 3 receitas saudáveis, criativas e práticas usando preferencialmente apenas esses ingredientes (você pode sugerir temperos básicos comuns como sal, óleo, azeite). Para cada receita inclua: nome, breve descrição, lista de ingredientes (com quantidades), modo de preparo passo a passo, e benefício nutricional principal. Responda em português brasileiro, formatando com markdown leve (negrito e listas)."

  @doc """
  Chat with streaming. `mode` is :fast or :smart.
  Sends {:chunk, text} and {:stream_done, full_text} to `caller_pid`.
  """
  def chat_stream(text, prior_messages, caller_pid, mode \\ :fast) do
    {provider_mod, model, api_key, fallback_mod, fallback_model, fallback_key} = resolve(mode)
    messages = build_chat_messages(text, prior_messages)

    opts = [model: model, api_key: api_key, system_prompt: @system_prompt, temperature: 0.7]

    case provider_mod.chat_stream(messages, caller_pid, opts) do
      :ok ->
        :ok

      {:error, _, reason} ->
        Logger.warning("[LLM] #{mode} provider #{provider_mod} failed: #{reason}, trying fallback")
        fallback_opts = [model: fallback_model, api_key: fallback_key, system_prompt: @system_prompt, temperature: 0.7]

        case fallback_mod.chat_stream(messages, caller_pid, fallback_opts) do
          :ok -> :ok
          {:error, _, fallback_reason} -> {:error, :llm_error, fallback_reason}
        end
    end
  end

  @doc """
  Non-streaming chat. Returns {:ok, text}.
  """
  def chat(text, prior_messages, mode \\ :fast) do
    {provider_mod, model, api_key, fallback_mod, fallback_model, fallback_key} = resolve(mode)
    messages = build_chat_messages(text, prior_messages)
    opts = [model: model, api_key: api_key, system_prompt: @system_prompt, temperature: 0.7]

    case provider_mod.chat(messages, opts) do
      {:ok, text} ->
        {:ok, text}

      {:error, _, reason} ->
        Logger.warning("[LLM] #{mode} provider #{provider_mod} failed: #{reason}, trying fallback")
        fallback_opts = [model: fallback_model, api_key: fallback_key, system_prompt: @system_prompt, temperature: 0.7]

        case fallback_mod.chat(messages, fallback_opts) do
          {:ok, text} -> {:ok, text}
          {:error, _, fallback_reason} -> {:error, :llm_error, fallback_reason}
        end
    end
  end

  @doc """
  Recipe generation (non-streaming).
  """
  def recipe(inventory_text, notes \\ nil, mode \\ :fast) do
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

    {provider_mod, model, api_key, fallback_mod, fallback_model, fallback_key} = resolve(mode)
    messages = [%{"role" => "user", "content" => prompt}]
    opts = [model: model, api_key: api_key, system_prompt: @recipe_prompt, temperature: 0.8]

    case provider_mod.chat(messages, opts) do
      {:ok, text} ->
        {:ok, text}

      {:error, _, reason} ->
        Logger.warning("[LLM] #{mode} recipe provider #{provider_mod} failed: #{reason}, trying fallback")
        fallback_opts = [model: fallback_model, api_key: fallback_key, system_prompt: @recipe_prompt, temperature: 0.8]

        case fallback_mod.chat(messages, fallback_opts) do
          {:ok, text} -> {:ok, text}
          {:error, _, fallback_reason} -> {:error, :llm_error, fallback_reason}
        end
    end
  end

  defp resolve(:fast) do
    config = Application.get_env(:nutria, :llm)
    fallback = if config[:fast_provider] == :google, do: :zen, else: :google
    {provider_for(config[:fast_provider]), config[:fast_model], api_key_for(config[:fast_provider]),
     provider_for(fallback), config[:smart_model], api_key_for(fallback)}
  end

  defp resolve(:smart) do
    config = Application.get_env(:nutria, :llm)
    fallback = if config[:smart_provider] == :google, do: :zen, else: :google
    {provider_for(config[:smart_provider]), config[:smart_model], api_key_for(config[:smart_provider]),
     provider_for(fallback), config[:fast_model], api_key_for(fallback)}
  end

  defp provider_for(:google), do: Nutria.LLM.Providers.Google
  defp provider_for(:zen), do: Nutria.LLM.Providers.Zen

  defp api_key_for(:google), do: Application.get_env(:nutria, :llm)[:google_api_key]
  defp api_key_for(:zen), do: Application.get_env(:nutria, :llm)[:zen_api_key]

  defp build_chat_messages(text, prior_messages) do
    prior_msgs =
      Enum.map(prior_messages, fn msg ->
        role = if msg.role == "user", do: "user", else: "assistant"
        %{"role" => role, "content" => msg.text}
      end)

    if prior_msgs != [] do
      prior_msgs ++ [%{"role" => "user", "content" => text}]
    else
      [%{"role" => "user", "content" => text}]
    end
  end
end
