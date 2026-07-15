defmodule SupportBotWeb.PageController do
  use SupportBotWeb, :controller

  def home(conn, _params), do: redirect(conn, to: ~p"/chat")

  def redirect_to_support(conn, _params),
    do: conn |> put_status(:moved_permanently) |> redirect(to: ~p"/support")

  def redirect_ticket_to_support(conn, %{"id" => id}),
    do: conn |> put_status(:moved_permanently) |> redirect(to: ~p"/support/#{id}")

  def redirect_to_docs(conn, _params),
    do: conn |> put_status(:moved_permanently) |> redirect(to: ~p"/docs")

  def redirect_kb_to_docs(conn, %{"slug" => slug}),
    do: conn |> put_status(:moved_permanently) |> redirect(to: ~p"/docs/#{slug}")
end
