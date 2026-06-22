defmodule SupportBotWeb.PageController do
  use SupportBotWeb, :controller

  def home(conn, _params), do: redirect(conn, to: ~p"/chat")
end
