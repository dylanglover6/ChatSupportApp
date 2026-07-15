defmodule SupportBotWeb.KBLive.Show do
  use SupportBotWeb, :live_view

  alias SupportBot.KB.Loader

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    article = Loader.get_by_slug(slug)

    if article do
      {:ok, assign(socket, page_title: article.title, article: article)}
    else
      {:ok, push_navigate(assign(socket, :page_title, "Knowledge Base"), to: ~p"/docs")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="panel">
      <p><.link navigate={~p"/docs"}>Back to Knowledge Base</.link></p>
      <h2>{@article.title}</h2>
      <p class="muted"><code>{@article.path}</code> · slug: {@article.slug}</p>
      <pre class="article-body"><%= @article.body %></pre>
    </section>
    """
  end
end
