defmodule SupportBot.KB.Search do
  @moduledoc "Small keyword search over local KB Markdown."

  alias SupportBot.KB.Loader

  @stopwords ~w(a an and are as at be by for from has have how i if in is it of on or our should the this to what when why with you your)

  def search(query, limit \\ 3) do
    tokens = tokenize(query)

    Loader.all()
    |> Enum.map(&score_article(&1, tokens))
    |> Enum.filter(fn {score, _article} -> score > 0 end)
    |> Enum.sort_by(fn {score, _article} -> score end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {_score, article} ->
      %{
        title: article.title,
        slug: article.slug,
        path: article.path,
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
    |> Enum.uniq()
  end

  defp score_article(article, tokens) do
    title = String.downcase(article.title)
    summary = String.downcase(Map.get(article, :summary, ""))
    body = String.downcase(article.body)

    score =
      Enum.reduce(tokens, 0, fn token, acc ->
        title_hits = if String.contains?(title, token), do: 4, else: 0
        summary_hits = if String.contains?(summary, token), do: 2, else: 0
        body_hits = Regex.scan(~r/\b#{Regex.escape(token)}\b/, body) |> length()
        acc + title_hits + summary_hits + body_hits
      end)

    {score, article}
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
