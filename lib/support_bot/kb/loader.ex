defmodule SupportBot.KB.Loader do
  @moduledoc "Loads DylanDocs Markdown articles from priv/kb, with frontmatter and rendered HTML."

  @category_order ["Start Here", "Skills", "Projects", "Career", "Personal", "Meta"]

  def all do
    kb_dir()
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.map(&load_doc/1)
    |> Enum.sort_by(&{category_rank(&1.category), &1.order, &1.title})
  end

  def get_by_slug(slug), do: Enum.find(all(), &(&1.slug == slug))

  def categories do
    all()
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {category, _docs} -> category_rank(category) end)
  end

  def prev_next(slug) do
    docs = all()

    case Enum.find_index(docs, &(&1.slug == slug)) do
      nil -> {nil, nil}
      0 -> {nil, Enum.at(docs, 1)}
      index -> {Enum.at(docs, index - 1), Enum.at(docs, index + 1)}
    end
  end

  defp load_doc(path) do
    raw = File.read!(path)
    {front, body} = split_frontmatter(raw)
    id = Path.basename(path, ".md")

    html =
      MDEx.to_html!(body, extension: [table: true, strikethrough: true, tasklist: true, autolink: true])

    %{
      slug: Map.get(front, "slug", id),
      title: Map.get(front, "title", "Untitled"),
      category: Map.get(front, "category", "Uncategorized"),
      order: front |> Map.get("order", "0") |> String.to_integer(),
      summary: Map.get(front, "summary", ""),
      body: body,
      html: html,
      path: Path.relative_to_cwd(path)
    }
  end

  defp split_frontmatter("---\n" <> rest) do
    case String.split(rest, ~r/\n---\n?/, parts: 2) do
      [frontmatter, body] -> {parse_frontmatter(frontmatter), String.trim_leading(body)}
      _ -> {%{}, rest}
    end
  end

  defp split_frontmatter(raw), do: {%{}, raw}

  defp parse_frontmatter(frontmatter) do
    frontmatter
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> {String.trim(key), String.trim(value)}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp category_rank(category) do
    case Enum.find_index(@category_order, &(&1 == category)) do
      nil -> length(@category_order)
      index -> index
    end
  end

  defp kb_dir, do: :code.priv_dir(:support_bot) |> Path.join("kb")
end
