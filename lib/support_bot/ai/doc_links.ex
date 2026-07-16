defmodule SupportBot.AI.DocLinks do
  @moduledoc """
  Turns DylanBot's `[[slug]]` references into real `/docs/:slug` links at render time.

  The model is instructed (see `SupportBot.AI.Prompts`) to reference DylanDocs pages
  as `[[slug]]`. Stored message content is left untouched — this is a display-only
  transform, applied to assistant messages when rendering the chat log.
  """

  alias SupportBot.KB.Loader

  @doc_ref ~r/\[\[([a-z0-9-]+)\]\]/

  @spec render(String.t()) :: Phoenix.HTML.safe()
  def render(content) do
    content
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> replace_refs()
    |> Phoenix.HTML.raw()
  end

  defp replace_refs(escaped_text) do
    Regex.replace(@doc_ref, escaped_text, fn _full, slug ->
      case Loader.get_by_slug(slug) do
        nil -> slug
        doc -> ~s(<a href="/docs/#{slug}">#{escape(doc.title)}</a>)
      end
    end)
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
