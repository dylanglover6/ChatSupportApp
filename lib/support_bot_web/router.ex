defmodule SupportBotWeb.Router do
  use SupportBotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_visitor_id
    plug :fetch_live_flash
    plug :put_root_layout, html: {SupportBotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Stamp a stable, random per-session id used as the rate-limit actor key. Not
  # security-sensitive on its own — just a spam/abuse throttle handle.
  defp put_visitor_id(conn, _opts) do
    case Plug.Conn.get_session(conn, :visitor_id) do
      nil ->
        id = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
        Plug.Conn.put_session(conn, :visitor_id, id)

      _ ->
        conn
    end
  end

  scope "/", SupportBotWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", ChatLive
    live "/support", TicketLive.Index
    live "/support/:id", TicketLive.Show
    live "/docs", KBLive.Index
    live "/docs/:slug", KBLive.Show

    # Legacy paths — permanent redirects to the renamed routes.
    get "/tickets", PageController, :redirect_to_support
    get "/tickets/:id", PageController, :redirect_ticket_to_support
    get "/kb", PageController, :redirect_to_docs
    get "/kb/:slug", PageController, :redirect_kb_to_docs
  end

  if Application.compile_env(:support_bot, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SupportBotWeb.Telemetry
    end
  end
end
