defmodule SupportBotWeb.KBLive.Index do
  use SupportBotWeb, :live_view

  alias SupportBot.KB.{Loader, Search}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "DylanDocs")
     |> assign(:categories, Loader.categories())
     |> assign(:current_slug, nil)
     |> assign(:introduction, Loader.get_by_slug("introduction"))
     |> assign(:search_query, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    results = if String.trim(query) == "", do: [], else: Search.search(query, 8)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="docs-layout">
      <details class="docs-sidebar-mobile">
        <summary>Browse DylanDocs</summary>
        <.docs_nav_tree categories={@categories} current_slug={@current_slug} />
      </details>

      <aside class="docs-sidebar-desktop">
        <.docs_nav_tree categories={@categories} current_slug={@current_slug} />
      </aside>

      <div class="docs-content">
        <form phx-change="search" class="docs-search">
          <input
            type="text"
            name="q"
            value={@search_query}
            placeholder="Search DylanDocs..."
            aria-label="Search DylanDocs"
            autocomplete="off"
          />
        </form>

        <div :if={@search_query != ""} class="docs-search-results">
          <h3>Search results</h3>
          <p :if={@search_results == []} class="muted">
            No matches for "{@search_query}".
          </p>
          <.link
            :for={result <- @search_results}
            navigate={~p"/docs/#{result.slug}"}
            class="docs-search-result"
          >
            <strong>{result.title}</strong>
            <p>{result.snippet}</p>
          </.link>
        </div>

        <div :if={@search_query == "" and @introduction} class="docs-article">
          {raw(@introduction.html)}
        </div>
      </div>
    </div>
    """
  end
end
