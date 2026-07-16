defmodule SupportBotWeb.KBLive.Show do
  use SupportBotWeb, :live_view

  alias SupportBot.KB.Loader

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Loader.get_by_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/docs")}

      article ->
        {prev, next} = Loader.prev_next(slug)

        {:ok,
         socket
         |> assign(:page_title, article.title)
         |> assign(:article, article)
         |> assign(:categories, Loader.categories())
         |> assign(:current_slug, slug)
         |> assign(:prev, prev)
         |> assign(:next, next)}
    end
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
        <p class="docs-breadcrumb">
          <.link navigate={~p"/docs"}>DylanDocs</.link> / {@article.category}
        </p>

        <div class="docs-article">
          {raw(@article.html)}
        </div>

        <div class="docs-ask-bot-hint">
          <p>Have a question about this page? <.link navigate={~p"/chat"}>Ask DylanBot →</.link></p>
        </div>

        <nav class="docs-prev-next">
          <.link :if={@prev} navigate={~p"/docs/#{@prev.slug}"} class="docs-prev">
            ← {@prev.title}
          </.link>
          <.link :if={@next} navigate={~p"/docs/#{@next.slug}"} class="docs-next">
            {@next.title} →
          </.link>
        </nav>
      </div>
    </div>
    """
  end
end
