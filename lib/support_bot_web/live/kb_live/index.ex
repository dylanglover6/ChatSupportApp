defmodule SupportBotWeb.KBLive.Index do
  use SupportBotWeb, :live_view

  alias SupportBot.KB.Loader

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Knowledge Base", articles: Loader.all())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="panel">
      <h2>Knowledge Base</h2>
      <p class="muted">These local Markdown articles power SupportBot keyword retrieval.</p>
      <div class="grid">
        <article :for={article <- @articles} class="card">
          <h3><.link navigate={~p"/kb/#{article.slug}"}>{article.title}</.link></h3>
          <p><code>{article.path}</code></p>
          <p>{article.body |> String.split("\n\n") |> Enum.at(1) |> String.slice(0, 260)}</p>
        </article>
      </div>
    </section>
    """
  end
end
