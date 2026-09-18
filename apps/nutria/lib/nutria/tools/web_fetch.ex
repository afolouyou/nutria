defmodule Nutria.Tools.WebFetch do
  @moduledoc """
  WebFetch tool — fetches pages from an allowlist of recipe sites.

  The allowlist is configured as `:web_fetch_sites` on `:nutria` (env `WEB_FETCH_SITES`,
  comma-separated host suffixes). Matching uses exact host or subdomain suffix
  (e.g. `allrecipes.com` matches `www.allrecipes.com` / `apollo.allrecipes.com`).

  When the page publishes a recipe as JSON-LD (schema.org Recipe), `fetch_recipe/1`
  extracts it into the canonical card shape used by the apps.
  """

  require Logger

  @max_bytes 1_000_000
  @text_limit 120_000
  @timeout_ms 10_000

  @entities %{
    "amp" => "&",
    "lt" => "<",
    "gt" => ">",
    "quot" => "\"",
    "apos" => "'",
    "nbsp" => " ",
    "oacute" => "ó",
    "eacute" => "é",
    "iacute" => "í",
    "aacute" => "á",
    "uacute" => "ú",
    "ocirc" => "ô",
    "ecirc" => "ê",
    "acirc" => "â",
    "ccedil" => "ç",
    "atilde" => "ã",
    "otilde" => "õ",
    "ntilde" => "ñ",
    "agrave" => "à",
    "igrave" => "ì",
    "ograve" => "ò",
    "ucirc" => "û",
    "icirc" => "î",
    "uuml" => "ü",
    "auml" => "ä",
    "oumll" => "ö",
    "euml" => "ë",
    "reg" => "®",
    "copy" => "©",
    "times" => "×",
    "sect" => "§"
  }

  @doc "Decodes named and numeric HTML entities (best-effort)."
  def decode_entities(text) when is_binary(text) do
    text
    |> replace_numeric_entities()
    |> replace_named_entities()
    |> replace_named_entities()
  end

  def decode_entities(other), do: other

  defp replace_numeric_entities(text) do
    Regex.replace(~r/&#x([0-9a-fA-F]+);/, text, fn _, hex ->
      <<String.to_integer(hex, 16)::utf8>>
    end)
    |> then(fn t ->
      Regex.replace(~r/&#(\d+);/, t, fn _, dec ->
        <<String.to_integer(dec)::utf8>>
      end)
    end)
  end

  defp replace_named_entities(text) do
    Regex.replace(~r/&([a-zA-Z]+);/, text, fn _, name ->
      Map.get(@entities, name, "&#{name} ")
    end)
  end

  @doc "List of allowed host suffixes (lowercased)."
  def sites do
    Application.get_env(:nutria, :llm, [])[:web_fetch_sites]
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&(String.downcase(String.trim(&1))))
  end

  @doc "WebFetch enabled? (allowlist non-empty)."
  def enabled?, do: sites() != []

  @doc "True when the URL's host is in the allowlist."
  def allowed_url?(url) do
    uri = URI.parse(url)

    case uri.host do
      host when is_binary(host) -> allowed_host?(String.downcase(host))
      _ -> false
    end
  end

  defp allowed_host?(host) do
    Enum.any?(sites(), fn site ->
      host == site || String.ends_with?(host, "." <> site)
    end)
  end

  @doc """
  Fetches a page from an allowed site.

  Returns:
  - `{:ok, %{text: text, recipe: recipe_map | nil, links: [] | [url]}}` when the page was fetched.
  - `{:error, :not_allowed, reason}` when the host is outside the allowlist.
  - `{:error, :fetch_failed, reason}` when the request failed (retryable).
  """
  def fetch(url) do
    if not allowed_url?(url) do
      {:error, :not_allowed,
       "Domínio fora da lista de sites permitidos. Use um dos sites receita autorizados."}
    else
      case request(url) do
        {:ok, %{status: 200, body: body}} when is_binary(body) ->
          body = if byte_size(body) > @max_bytes, do: String.slice(body, 0, @max_bytes), else: body

          recipe = extract_recipe(body, url)
          links = recipe_links(body, url)

          text_body =
            if byte_size(body) > @text_limit, do: String.slice(body, 0, @text_limit), else: body

          {:ok, %{text: html_to_text(text_body), recipe: recipe, links: links}}

        {:ok, %{status: status}} ->
          {:error, :fetch_failed, "Página retornou HTTP #{status}"}

        {:error, reason} ->
          Logger.warning("[WebFetch] fetch error: #{inspect(reason)}")
          {:error, :fetch_failed, "Falha ao buscar a página na web"}
      end
    end
  end

  @doc """
  Extracts absolute URLs of recipe pages found in a page (anchor hrefs pointing to
  recipe paths). Used to follow up from search/listing pages that don't expose JSON-LD.
  """
  @doc since: "2025.1.0"
  def recipe_links(html, url) do
    with {:ok, doc} <- Floki.parse_document(html) do
      doc
      |> Floki.find("a[href]")
      |> Floki.attribute("href")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.filter(&recipe_href?/1)
      |> Enum.map(&absolute_url(url, &1))
      |> Enum.uniq()
    else
      _ -> []
    end
  end

  @doc "First recipe link found on the page, or nil."
  @doc since: "2025.1.0"
  def first_recipe_url(html, url), do: html |> recipe_links(url) |> List.first()

  @doc """
  Formats a canonical recipe map as readable text for the LLM context.
  """
  @doc since: "2025.1.0"
  def recipe_context(recipe) do
    name = Map.get(recipe, "name", "")
    desc = Map.get(recipe, "description", "")

    meta =
      [
        Map.get(recipe, "prep_min") && "Tempo de preparo: #{Map.get(recipe, "prep_min")} min",
        Map.get(recipe, "cook_min") && "Tempo de cozimento: #{Map.get(recipe, "cook_min")} min",
        Map.get(recipe, "servings") && "Rendimento: #{Map.get(recipe, "servings")} porções"
      ]
      |> Enum.reject(&(&1 == false or &1 == nil))

    ingredients =
      recipe
      |> Map.get("ingredients", [])
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {i, n} -> "  #{n}. #{i}" end)

    steps =
      recipe
      |> Map.get("steps", [])
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {s, n} -> "  #{n}. #{s}" end)

    meta_txt = if meta == [], do: "", else: Enum.join(meta, " · ")

    """
    Receita encontrada: #{name}
    #{desc}

    #{meta_txt}

    Ingredientes:
    #{ingredients}

    Modo de preparo:
    #{steps}

    Fonte: #{Map.get(recipe, "source", "")} (#{Map.get(recipe, "source_url", "")})
    """
  end

  defp recipe_href?(href) do
    down = String.downcase(href)

    String.match?(down, ~r{/(?:receita|recipe|recepten?|rezept|ricetta|receitas)/i}) ||
      String.contains?(down, "receita")
  end

  defp absolute_url(base_url, href) do
    cond do
      String.starts_with?(href, "http://") or String.starts_with?(href, "https://") ->
        href

      String.starts_with?(href, "//") ->
        "https:" <> href

      true ->
        uri = URI.parse(base_url)
        origin = "#{uri.scheme || "https"}://#{uri.host || ""}"

        if String.starts_with?(href, "/") do
          origin <> href
        else
          origin <> "/" <> href
        end
    end
  end

  @doc """
  Fetches and extracts a recipe JSON-LD from an allowed site.
  Returns `{:ok, recipe_map}` where the map follows the canonical card shape.
  """
  def fetch_recipe(url) do
    case fetch(url) do
      {:ok, %{recipe: %{} = recipe}} -> {:ok, recipe}
      {:ok, %{recipe: nil}} -> {:error, :no_recipe, "Nenhuma receita esquematizada encontrada na página"}
      {:error, _, _} = error -> error
    end
  end

  defp request(url) do
    req =
      Req.new(
        method: :get,
        url: url,
        headers: %{
          "user-agent" => "Mozilla/5.0 (NutrIA/1.0; +https://nutria.app)",
          "accept" => "text/html,application/xhtml+xml,application/ld+json"
        },
        receive_timeout: @timeout_ms
      )

    case Req.request(req) do
      {:ok, resp} -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  defp html_to_text(html) do
  html
  |> String.replace(~r/<script\b[^>]*>[\s\S]*?<\/script>/i, " ")
  |> String.replace(~r/<style\b[^>]*>[\s\S]*?<\/style>/i, " ")
  |> String.replace(~r/<noscript\b[^>]*>[\s\S]*?<\/noscript>/i, " ")
  |> String.replace(~r/<(?:header|nav|footer|iframe|svg|form)\b[^>]*>[\s\S]*?<\/(?:header|nav|footer|iframe|svg|form)>/i, " ")
  |> then(fn cleaned ->
    case Floki.parse_document(cleaned) do
      {:ok, doc} ->
        doc
        |> Floki.text(sep: "\n")
        |> String.replace(~r/[ \t]+/, " ")
        |> String.replace(~r/\n{3,}/, "\n\n")
        |> String.trim()

      _ ->
        ""
    end
  end)
end

  @doc false
  def extract_recipe(html, url) do
    with {:ok, doc} <- Floki.parse_document(html) do
      scripts = Floki.find(doc, "script[type='application/ld+json']")

      case find_recipe_json(scripts) do
        nil -> nil
        ld -> normalize_recipe(ld, url)
      end
    else
      _ -> nil
    end
  end

  defp find_recipe_json(scripts) do
    Enum.reduce_while(scripts, nil, fn {_, _, children}, acc ->
      json =
        children
        |> Floki.text()
        |> String.trim()

      case Jason.decode(json) do
        {:ok, decoded} ->
          case find_recipe(decoded) do
            nil -> {:cont, acc}
            recipe -> {:halt, recipe}
          end

        {:error, _} ->
          {:cont, acc}
      end
    end)
  end

  @doc false
  def find_recipe(data)

  def find_recipe(%{"@type" => type} = node) do
    if recipe_type?(type) do
      node
    else
      node
      |> Map.values()
      |> Enum.find_value(&find_recipe/1)
    end
  end

  def find_recipe(%{"@graph" => graph}), do: Enum.find_value(graph, &find_recipe/1)
  def find_recipe(%{"itemListElement" => items}) when is_list(items), do: Enum.find_value(items, &find_recipe/1)
  def find_recipe(list) when is_list(list), do: Enum.find_value(list, &find_recipe/1)
  def find_recipe(%{} = map), do: Map.values(map) |> Enum.find_value(&find_recipe/1)
  def find_recipe(_), do: nil

  defp recipe_type?("Recipe"), do: true
  defp recipe_type?([_ | _] = t), do: Enum.member?(t, "Recipe")
  defp recipe_type?(_), do: false

  @doc "ISO-8601 duration (PT10M, PT1H30M) -> minutes."
  def duration_to_min(nil), do: nil
  def duration_to_min(""), do: nil

  def duration_to_min(dur) when is_binary(dur) do
    dur = String.trim(dur)
    hours = Regex.scan(~r/(\d+)H/, dur) |> List.flatten() |> Enum.at(1, "0")
    minutes = Regex.scan(~r/(\d+)M/, dur) |> List.flatten() |> Enum.at(1, "0")

    case {Integer.parse(hours), Integer.parse(minutes)} do
      {{h, _}, {m, _}} -> h * 60 + m
      _ -> nil
    end
  end

  def duration_to_min(_), do: nil

  defp normalize_recipe(ld, url) do
    %{
      "name" => str(ld, "name", nil) |> decode_entities(),
      "description" => str(ld, "description", nil) |> decode_entities(),
      "image" => image(ld),
      "prep_min" => duration_to_min(json_get(ld, "prepTime")),
      "cook_min" => duration_to_min(json_get(ld, "cookTime")),
      "total_min" => duration_to_min(json_get(ld, "totalTime")),
      "servings" => servings(ld),
      "ingredients" => ingredients(ld),
      "steps" => steps(ld),
      "nutrition" => nutrition(ld),
      "source" => source_name(url),
      "source_url" => url
    }
  end

  defp json_get(map, key), do: Map.get(map, key)

  defp str(map, key, default) do
    case json_get(map, key) do
      s when is_binary(s) and s != "" -> String.trim(s)
      _ -> default
    end
  end

  defp image(ld) do
    case json_get(ld, "image") do
      %{"url" => url} when is_binary(url) -> url
      [%{"url" => url} | _] when is_binary(url) -> url
      [url | _] when is_binary(url) -> url
      url when is_binary(url) -> url
      _ -> nil
    end
  end

  defp servings(ld) do
    case json_get(ld, "recipeYield") do
      [s | _] when is_binary(s) -> parse_servings(s)
      s when is_binary(s) -> parse_servings(s)
      n when is_integer(n) -> n
      _ -> nil
    end
  end

  defp parse_servings(s) do
    case Regex.run(~r/(\d+)/, s) do
      [_, num] -> String.to_integer(num)
      _ -> nil
    end
  end

  defp ingredients(ld) do
    case json_get(ld, "recipeIngredient") do
      list when is_list(list) ->
        list
        |> Enum.map(&clean_ingredient/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end

  defp clean_ingredient(s) when is_binary(s) do
    s
    |> decode_entities()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp clean_ingredient(_), do: ""

  defp steps(ld) do
    case json_get(ld, "recipeInstructions") do
      list when is_list(list) -> flatten_steps(list)
      _ -> []
    end
  end

  defp flatten_steps(list) do
    Enum.flat_map(list, fn
      %{"@type" => "HowToSection", "itemListElement" => inner} ->
        inner |> Enum.map(&step_text/1) |> Enum.reject(&(&1 == ""))

      %{"text" => text} when is_binary(text) ->
        [String.trim(text)]

      _ ->
        []
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp step_text(%{"text" => text}) when is_binary(text), do: text |> String.trim() |> decode_entities()
  defp step_text(_), do: ""

  defp nutrition(ld) do
    case json_get(ld, "nutrition") do
      %{} = n ->
        [
          %{"label" => "Calorias", "value" => value(n, "calories")},
          %{"label" => "Carbo", "value" => value(n, "carbohydrateContent")},
          %{"label" => "Proteína", "value" => value(n, "proteinContent")},
          %{"label" => "Gordura", "value" => value(n, "fatContent")}
        ]
        |> Enum.reject(&(&1["value"] == "—"))

      _ ->
        []
    end
  end

  defp value(map, key) do
    case json_get(map, key) do
      v when is_binary(v) and v != "" -> v
      v when is_number(v) -> "#{v}"
      _ -> "—"
    end
  end

  defp source_name(url) do
    uri = URI.parse(url)

    case uri.host do
      nil -> "Web"
      host -> host |> String.replace(~r/^www\./, "") |> String.split(".") |> hd() |> String.capitalize()
    end
  end
end