defmodule SupportBotWeb.CoreComponents do
  use Phoenix.Component

  attr :kind, :string, default: "neutral"
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={"badge badge-#{@kind}"}>{render_slot(@inner_block)}</span>
    """
  end
end
