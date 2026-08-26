defmodule SupportBot.KB.Search do
  @moduledoc "Small keyword search over local KB Markdown."

  alias SupportBot.KB.Loader

  # "dylan"/"glover" are non-discriminative here — the whole site is about Dylan Glover,
  # so his name appears in nearly every doc and would otherwise drown out real signal.
  @stopwords ~w(a an and are as at be by for from has have how i if in is it of on or our should the this to what when why with you your dylan dylans glover me my his him he where does did done)

  # Relevance gate for the source links we surface: a match must clear an absolute
  # floor (so a single trivial body mention never qualifies) AND reach a fraction of
  # the top-scoring doc (so trailing noise is dropped once there's a clear winner).
  # If nothing clears the gate we return [], and the UI shows no source chips.
  @min_score 3
  @relative_floor 0.45

  def search(query, limit \\ 3) do
    tokens = tokenize(query)

    scored =
      Loader.all(include_hidden: true)
      |> Enum.map(&score_article(&1, tokens))
      |> Enum.filter(fn {score, _strong?, _article} -> score >= @min_score end)
      |> Enum.sort_by(fn {score, _strong?, _article} -> score end, :desc)

    # Prefer docs that matched in a title/category/summary (a real topic match)
    # over docs that only matched a word in the body. A generic query token like
    # "work" mentioned in passing shouldn't surface Languages/Tooling alongside
    # Work History. Only fall back to body-only matches when nothing matched a
    # strong field, so queries whose answer lives purely in body text still work.
    scored =
      case Enum.filter(scored, fn {_score, strong?, _article} -> strong? end) do
        [] -> scored
        strong -> strong
      end

    top_score =
      case scored do
        [{score, _strong?, _article} | _] -> score
        [] -> 0
      end

    cutoff = top_score * @relative_floor

    scored
    |> Enum.filter(fn {score, _strong?, _article} -> score >= cutoff end)
    |> Enum.take(limit)
    |> Enum.map(fn {_score, _strong?, article} ->
      %{
        title: article.title,
        slug: article.slug,
        path: article.path,
        summary: Map.get(article, :summary, ""),
        snippet: snippet(article.body, tokens)
      }
    end)
  end

  defp tokenize(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, " ")
    |> String.split()
    |> Enum.reject(&(&1 in @stopwords or String.length(&1) < 3))
    |> Enum.map(&stem/1)
    |> Enum.reject(&(String.length(&1) < 3))
    |> Enum.uniq()
  end

  # Light suffix stripping so "worked"/"working"/"works" all reduce to "work" and
  # match the "Work History" doc. Not linguistically perfect, just enough to stop
  # inflected query words from missing the doc that answers them.
  defp stem(token) do
    cond do
      String.ends_with?(token, "ing") and String.length(token) > 5 ->
        String.slice(token, 0..-4//1)

      String.ends_with?(token, "ed") and String.length(token) > 4 ->
        String.slice(token, 0..-3//1)

      String.ends_with?(token, "es") and String.length(token) > 4 ->
        String.slice(token, 0..-3//1)

      String.ends_with?(token, "s") and not String.ends_with?(token, "ss") and
          String.length(token) > 3 ->
        String.slice(token, 0..-2//1)

      true ->
        token
    end
  end

  defp score_article(article, tokens) do
    title = String.downcase(article.title)
    summary = String.downcase(Map.get(article, :summary, ""))
    category = String.downcase(Map.get(article, :category, ""))
    body = String.downcase(article.body)

    {score, strong?} =
      Enum.reduce(tokens, {0, false}, fn token, {acc, strong?} ->
        # Word-boundary prefix match everywhere: "work" matches "Work History" and
        # "worked", but NOT "frameworks". Plain substring used to hand "frameworks"
        # a bogus title hit for the token "work". Prefix keeps inflected forms.
        re = ~r/\b#{Regex.escape(token)}[a-z]*\b/
        # Match the doc's category too, so "projects" surfaces the Projects docs,
        # "skills" the Skills docs, etc. — even when the body never says the word.
        title_hits = if Regex.match?(re, title), do: 4, else: 0
        category_hits = if Regex.match?(re, category), do: 4, else: 0
        summary_hits = if Regex.match?(re, summary), do: 2, else: 0
        body_hits = Regex.scan(re, body) |> length()
        # "strong" = matched the doc's title or category (its real topic), not a
        # passing mention in the summary or body. Summary/body still add to score
        # for ranking; they just don't make a doc a topic match on their own.
        strong? = strong? or title_hits > 0 or category_hits > 0
        {acc + title_hits + category_hits + summary_hits + body_hits, strong?}
      end)

    {score, strong?, article}
  end

  defp snippet(body, []), do: body |> String.slice(0, 260) |> String.trim()

  defp snippet(body, tokens) do
    paragraphs = String.split(body, ~r/\n\s*\n/)

    selected =
      Enum.find(paragraphs, fn paragraph ->
        lower = String.downcase(paragraph)
        Enum.any?(tokens, &String.contains?(lower, &1))
      end) || Enum.at(paragraphs, 1) || body

    selected
    |> String.replace(~r/\s+/, " ")
    |> String.slice(0, 320)
    |> String.trim()
  end
end
