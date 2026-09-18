defmodule Nutria.LLM do
  @moduledoc """
  Multi-provider LLM router.
  Dispatches to the right provider based on mode (fast/smart) with fallback.
  """
  require Logger

  @providers [:google, :zen, :deepseek]

  @max_prior_messages 20
  @max_prior_chars 12_000
  @max_page_chars 12_000

  @system_prompt """
  Você é o NutrIA, assistente nutricional brasileiro. Seja conciso e direto.

  Regras:
  - Máximo 200 palavras
  - Use markdown simples: **negrito**, listas com - e tabelas quando útil
  - Para análises: nutrientes principais + nota 1-10
  - Para planos: horário + refeição + alimentos
  - Se não souber, admita
  - Se o usuário pedir para adicionar/remover itens da despensa, responda brevemente e inclua
    ao final um bloco exato <PANTRY>{"add":[{"name":"maçã","quantity":2,"unit":"un"}],"remove":[{"name":"arroz"}]}</PANTRY>
  - O bloco <PANTRY>...</PANTRY> é apenas uma instrução interna para o sistema.
    NUNCA o mostre nem explique seu código na resposta visível ao usuário.
  """

  @tool_decision_prompt """
  Você é um roteador de intenções. Baseado no pedido do usuário, responda APENAS com JSON válido, sem texto extra:

  - Se o usuário pediu para buscar/pesquisar uma receita ou conteúdo em um site receita específico (ou citou um deles): {"action":"webfetch","url":"<URL https completa>","reason":"<motivo curto>"}
  - Se o usuário pediu busca na web mas não deu site/URL e você não sabe a URL exata: {"action":"webfetch_unavailable","reason":"<o que faltou>"}
  - Caso contrário (pergunta normal, cálculo, plano, análise da despensa, conversa): {"action":"answer"}

  Regras:
  - Use SOMENTE URLs de domínios da lista permitida abaixo. Nunca invente URLs que não existam nesses domínios.
  - Para usuário brasileiro (pedido em português, sem site indicado): prefira https://www.tudogostoso.com.br
  - Para BUSCA de receita sem URL exata, SEMPRE retorne a URL de busca do domínio com o termo:
    https://www.tudogostoso.com.br/busca?q=<termo>+<termo2> (palavras separadas por +, sem espaços).
    NUNCA retorne a home nem páginas de categoria do domínio.
  - Só retorne URL direta de receita quando o usuário citar o prato e você tiver certeza da URL.
  """

  @recipe_prompt """
  Você é o NutrIA, um chef nutricional criativo.
  Dada uma lista de ingredientes disponíveis, sugira 1 receita saudável e prática.

  Para a receita inclua:
  - Nome criativo
  - Ingredientes com quantidades exatas
  - Modo de preparo em passos numerados
  - Benefício nutricional em 1 frase

  Ao final, inclua um bloco JSON delimitado por <USAGE>...</USAGE>:
  <USAGE>[{"name":"arroz","quantity":0.4,"unit":"kg"}]</USAGE>

  Também inclua um bloco JSON delimitado por <RECIPE>...</RECIPE> com a estrutura exata:
  <RECIPE>{"name":"nome da receita","description":"benefício em 1 frase","prep_min":15,"cook_min":20,"servings":2,"nutrition":[{"label":"Calorias","value":"320 kcal"},{"label":"Carboidratos","value":"35g"}],"ingredients":["2 xícaras de arroz integral","1 cebola picada"],"steps":["Passo 1: ...","Passo 2: ..."]}</RECIPE>

  Regras:
  - Use os mesmos nomes e unidades dos itens da despensa
  - Não consuma mais do que está disponível
  - Sugira temperos básicos se necessário (sal, óleo, azeite)
  - Responda em português brasileiro com markdown leve
  - nutrition aceita até 4 itens (Calorias, Carboidratos, Proteína, Gordura); omita se preferir ([])
  """

  @doc """
  Chat with streaming. `mode` is :fast or :smart.
  Sends {:chunk, text} and {:stream_done, full_text} to `caller_pid`.
  `extra_context` (optional) is injected as an earlier turn (used for webfetch enrichment).
  """
  def chat_stream(text, prior_messages, caller_pid, mode \\ :fast, extra_context \\ nil) do
    {provider_mod, model, api_key, fallback_mod, fallback_model, fallback_key} = resolve(mode)
    messages = build_chat_messages(text, prior_messages, extra_context)

    opts = [model: model, api_key: api_key, system_prompt: @system_prompt, temperature: 0.3]

    case provider_mod.chat_stream(messages, caller_pid, opts) do
      :ok ->
        :ok

      {:error, _, reason} ->
        Logger.warning(
          "[LLM] #{mode} provider #{provider_mod} failed: #{reason}, trying fallback"
        )

        fallback_opts = [
          model: fallback_model,
          api_key: fallback_key,
          system_prompt: @system_prompt,
          temperature: 0.3
        ]

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
    opts = [model: model, api_key: api_key, system_prompt: @system_prompt, temperature: 0.3]

    case provider_mod.chat(messages, opts) do
      {:ok, text} ->
        {:ok, text}

      {:error, _, reason} ->
        Logger.warning(
          "[LLM] #{mode} provider #{provider_mod} failed: #{reason}, trying fallback"
        )

        fallback_opts = [
          model: fallback_model,
          api_key: fallback_key,
          system_prompt: @system_prompt,
          temperature: 0.3
        ]

        case fallback_mod.chat(messages, fallback_opts) do
          {:ok, text} -> {:ok, text}
          {:error, _, fallback_reason} -> {:error, :llm_error, fallback_reason}
        end
    end
  end

  @doc """
  Agent chat (used by :smart mode). Routes to webfetch enrichment when the user
  asks for content from an allowed recipe site, otherwise streams normally.
  """
  def agent_chat(text, prior_messages, caller_pid, mode) do
    if Nutria.Tools.WebFetch.enabled?() and webfetch_intent?(text) do
      case decide_action(text, prior_messages, mode) do
        {:ok, %{"action" => "webfetch", "url" => url}} when is_binary(url) ->
          handle_webfetch(text, prior_messages, caller_pid, mode, url)

        {:ok, %{"action" => "webfetch_unavailable"}} ->
          send(caller_pid, {:assistant_note,
            "Não tenho acesso a esse conteúdo diretamente. Segue minha resposta:"})

          chat_stream(text, prior_messages, caller_pid, mode)

        _ ->
          chat_stream(text, prior_messages, caller_pid, mode)
      end
    else
      chat_stream(text, prior_messages, caller_pid, mode)
    end
  end

  defp webfetch_intent?(text) do
    site_names =
      Nutria.Tools.WebFetch.sites()
      |> Enum.flat_map(fn site ->
        site
        |> String.split(".")
        |> List.delete_at(-1)
      end)

    pattern =
      ~r/(?:busque|buscar|pesquis|pesquisa|na web|internet|site do|receita do|webfetch|receitas de site|#{Enum.map_join(site_names, "|", &Regex.escape/1)}|#{Enum.map_join(Nutria.Tools.WebFetch.sites(), "|", &Regex.escape/1)})/i

    String.match?(text, pattern)
  end

  defp decide_action(text, prior_messages, mode) do
    {provider_mod, model, api_key, _, _, _} = resolve(mode)
    messages = build_chat_messages(text, prior_messages)

    opts = [
      model: model,
      api_key: api_key,
      system_prompt: @tool_decision_prompt <> "\n\nDomínios permitidos:\n" <> sites_listing(),
      temperature: 0.0
    ]

    case provider_mod.chat(messages, opts) do
      {:ok, response} ->
        case extract_json(response) do
          {:ok, %{"action" => action} = decision} -> {:ok, Map.put(decision, "action", action)}
          _ -> :error
        end

      {:error, _, _} ->
        :error
    end
  end

  defp extract_json(text) do
    trimmed = String.trim(text)

    stripped =
      trimmed
      |> String.replace(~r/^```(?:json)?\s*/i, "")
      |> String.replace(~r/\s*```$/, "")

    case Jason.decode(stripped) do
      {:ok, _} = ok ->
        ok

      {:error, _} ->
        case Regex.run(~r/\{.*\}/s, trimmed) do
          [json] -> Jason.decode(json)
          nil -> {:error, :no_json}
        end
    end
  end

  defp handle_webfetch(text, prior_messages, caller_pid, mode, url) do
    host = (URI.parse(url).host || "site") |> String.replace(~r/^www\./, "")
    Logger.info("[LLM] webfetch url=#{url}")

    case Nutria.Tools.WebFetch.fetch(url) do
      {:ok, %{recipe: %{} = recipe}} ->
        Logger.info("[LLM] webfetch got structured recipe for #{url}")
        send(caller_pid, {:thinking_title, "Encontrei a receita em #{host}..."})
        chat_stream(text, prior_messages, caller_pid, mode, web_context(recipe, url))

      {:ok, %{recipe: nil, links: [first | _]}} ->
        Logger.info("[LLM] webfetch #{url} → following #{first}")
        send(caller_pid, {:thinking_title, "Abrindo a melhor receita em #{host}..."})
        follow_up_recipe(text, prior_messages, caller_pid, mode, first)

      {:ok, %{text: page_text}} when byte_size(page_text) > 300 ->
        send(caller_pid, {:thinking_title, "Buscando em #{host}..."})

        chat_stream(text, prior_messages, caller_pid, mode, page_context(page_text, url))

      {:ok, %{text: page_text}} ->
        Logger.warning("[LLM] webfetch page for #{url} is too thin (#{byte_size(page_text)}b)")

        send(caller_pid, {:assistant_note,
          "Encontrei a página #{host} mas ela não tem conteúdo legível. Segue minha resposta:"})

        chat_stream(text, prior_messages, caller_pid, mode)

      {:error, code, detail} when code in [:not_allowed, :fetch_failed] ->
        Logger.warning("[LLM] webfetch failed for #{url}: #{detail}")
        send(caller_pid, {:assistant_note, "Não consegui acessar #{url}. Segue minha resposta:"})
        chat_stream(text, prior_messages, caller_pid, mode)
    end
  end

  defp follow_up_recipe(text, prior_messages, caller_pid, mode, url) do
    if Nutria.Tools.WebFetch.allowed_url?(url) do
      case Nutria.Tools.WebFetch.fetch(url) do
        {:ok, %{recipe: %{} = recipe}} ->
          chat_stream(text, prior_messages, caller_pid, mode, web_context(recipe, url))

        {:ok, %{text: page_text}} when byte_size(page_text) > 300 ->
          chat_stream(text, prior_messages, caller_pid, mode, page_context(page_text, url))

        {:ok, _} ->
          send(caller_pid, {:assistant_note, "Não encontrei conteúdo legível na receita. Segue minha resposta:"})
          chat_stream(text, prior_messages, caller_pid, mode)

        {:error, _, detail} ->
          Logger.warning("[LLM] follow-up webfetch failed for #{url}: #{detail}")
          send(caller_pid, {:assistant_note, "Não consegui abrir a receita. Segue minha resposta:"})
          chat_stream(text, prior_messages, caller_pid, mode)
      end
    else
      send(caller_pid, {:assistant_note, "O resultado apontou para um site fora da lista permitida. Segue minha resposta:"})
      chat_stream(text, prior_messages, caller_pid, mode)
    end
  end

  defp web_context(recipe, url) do
    """
    Conteúdo estruturado obtido de #{url} (fonte) para responder a pergunta do usuário.
    Resuma em português brasileiro e cite a fonte ao final.

    ===== RECEITA =====
    #{Nutria.Tools.WebFetch.recipe_context(recipe)}
    ===== FIM DA RECEITA =====
    """
  end

  defp page_context(page_text, url) do
    """
    Conteúdo obtido de #{url} (fonte) para responder a pergunta do usuário.
    Resuma em português brasileiro. Respeite direitos: cite a fonte ao final.

    ===== INÍCIO DA PÁGINA =====
    #{String.slice(page_text, 0, @max_page_chars)}
    ===== FIM DA PÁGINA =====
    """
  end

  @doc """
  Recipe generation (non-streaming).
  """
  def recipe(inventory_text, notes \\ nil, mode \\ :fast) do
    prompt = build_recipe_prompt(inventory_text, notes)
    call_non_streaming(prompt, mode, @recipe_prompt, 0.8)
  end

  defp call_non_streaming(prompt, mode, system_prompt, temperature) do
    {provider_mod, model, api_key, fallback_mod, fallback_model, fallback_key} = resolve(mode)
    messages = [%{"role" => "user", "content" => prompt}]

    opts = [
      model: model,
      api_key: api_key,
      system_prompt: system_prompt,
      temperature: temperature
    ]

    case provider_mod.chat(messages, opts) do
      {:ok, text} ->
        {:ok, text}

      {:error, _, reason} ->
        Logger.warning(
          "[LLM] #{mode} recipe provider #{provider_mod} failed: #{reason}, trying fallback"
        )

        fallback_opts = [
          model: fallback_model,
          api_key: fallback_key,
          system_prompt: system_prompt,
          temperature: temperature
        ]

        case fallback_mod.chat(messages, fallback_opts) do
          {:ok, text} -> {:ok, text}
          {:error, _, fallback_reason} -> {:error, :llm_error, fallback_reason}
        end
    end
  end

  defp build_recipe_prompt(inventory_text, notes) do
    prompt = """
    Itens disponíveis na despensa do usuário:
    #{inventory_text}

    Sugira UMA receita prática e saudável usando esses ingredientes.
    Inclua: nome, ingredientes com quantidades exatas, modo de preparo, benefício nutricional.

    IMPORTANTE: Ao final, inclua um bloco JSON delimitado por <USAGE>...</USAGE> listando o que foi consumido,
    no formato exato: <USAGE>[{"name":"arroz","quantity":0.4,"unit":"kg"}]</USAGE>.
    Use os mesmos nomes (case-insensitive) e unidades dos itens da despensa.
    Não consuma mais do que está disponível.

    Também inclua ao final um bloco <RECIPE>...</RECIPE> com JSON desta forma:
    <RECIPE>{"name":"nome da receita","description":"benefício em 1 frase","prep_min":15,"cook_min":20,"servings":2,"nutrition":[{"label":"Calorias","value":"320 kcal"},{"label":"Carboidratos","value":"35g"}],"ingredients":["2 xícaras de arroz integral","1 cebola picada"],"steps":["Passo 1: ...","Passo 2: ..."]}</RECIPE>
    """

    if notes && String.trim(notes) != "" do
      prompt <> "\nObservações: #{notes}"
    else
      prompt
    end
  end

  defp resolve(:fast) do
    config = Application.get_env(:nutria, :llm)
    fallback = if config[:fast_provider] == :google, do: :zen, else: :google

    {provider_for(config[:fast_provider]), config[:fast_model],
     api_key_for(config[:fast_provider]), provider_for(fallback), config[:smart_model],
     api_key_for(fallback)}
  end

  defp resolve(:smart) do
    config = Application.get_env(:nutria, :llm)
    fallback = if config[:smart_provider] == :google, do: :zen, else: :google

    {provider_for(config[:smart_provider]), config[:smart_model],
     api_key_for(config[:smart_provider]), provider_for(fallback), config[:fast_model],
     api_key_for(fallback)}
  end

  defp provider_for(:google), do: Nutria.LLM.Providers.Google
  defp provider_for(:zen), do: Nutria.LLM.Providers.Zen
  defp provider_for(:deepseek), do: Nutria.LLM.Providers.DeepSeek

  defp api_key_for(:google), do: Application.get_env(:nutria, :llm)[:google_api_key]
  defp api_key_for(:zen), do: Application.get_env(:nutria, :llm)[:zen_api_key]
  defp api_key_for(:deepseek), do: Application.get_env(:nutria, :llm)[:deepseek_api_key]

  defp sites_listing do
    Nutria.Tools.WebFetch.sites()
    |> Enum.join("\n")
  end

  defp build_chat_messages(text, prior_messages, extra_context \\ nil) do
    prior_msgs =
      prior_messages
      |> Enum.take(-@max_prior_messages)
      |> trim_context_chars(@max_prior_chars)
      |> Enum.map(fn msg ->
        role = if msg.role == "user", do: "user", else: "assistant"
        %{"role" => role, "content" => msg.text}
      end)

    context_msgs =
      case extra_context do
        nil -> []
        ctx -> [%{"role" => "user", "content" => ctx}]
      end

    base = prior_msgs ++ context_msgs

    if base != [] do
      base ++ [%{"role" => "user", "content" => text}]
    else
      [%{"role" => "user", "content" => text}]
    end
  end

  defp trim_context_chars(messages, max_chars) do
    messages
    |> Enum.reverse()
    |> accum_fit(max_chars, 0)
    |> Enum.reverse()
  end

  defp accum_fit([], _max, _total), do: []

  defp accum_fit([msg | rest], max_chars, total) do
    size = String.length(msg.text || "")

    if total + size <= max_chars do
      [msg | accum_fit(rest, max_chars, total + size)]
    else
      []
    end
  end
end
