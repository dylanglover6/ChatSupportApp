defmodule SupportBotWeb.CoreComponents do
  use Phoenix.Component
  use SupportBotWeb, :verified_routes

  attr :kind, :string, default: "neutral"
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={"badge badge-#{@kind}"}>{render_slot(@inner_block)}</span>
    """
  end

  attr :categories, :list, required: true
  attr :current_slug, :string, default: nil

  def docs_nav_tree(assigns) do
    ~H"""
    <nav class="docs-nav-tree">
      <div :for={{category, docs} <- @categories} class="docs-nav-group">
        <h4>{category}</h4>
        <.link
          :for={doc <- docs}
          navigate={~p"/docs/#{doc.slug}"}
          class={["docs-nav-link", doc.slug == @current_slug && "is-active"]}
        >
          {doc.title}
        </.link>
      </div>
    </nav>
    """
  end
end
