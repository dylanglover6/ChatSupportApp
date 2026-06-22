defmodule SupportBot.KB.Loader do
  @moduledoc "Loads local Markdown knowledge base articles from priv/kb."

  def all do
    kb_dir()
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&load_article/1)
  end

  def get_by_slug(slug), do: Enum.find(all(), &(&1.slug == slug))

  defp load_article(path) do
    body = File.read!(path)
    id = path |> Path.basename(".md")
    title = extract_title(body)

    %{
      id: id,
      slug: slugify(id),
      title: title,
      path: Path.relative_to_cwd(path),
      body: body
    }
  end

  defp extract_title(body) do
    body
    |> String.split("\n")
    |> Enum.find_value("Untitled Article", fn
      "# " <> title -> String.trim(title)
      _ -> nil
    end)
  end

  defp slugify(id) do
    id
    |> String.replace(~r/^\d+_/, "")
    |> String.replace("_", "-")
  end

  defp kb_dir, do: :code.priv_dir(:support_bot) |> Path.join("kb")
end
