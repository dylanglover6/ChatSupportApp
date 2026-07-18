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

  # A visit "session" handle: a random visitor id plus a rolling last-seen timestamp,
  # both in the signed session cookie. On every request we refresh last-seen; if the
  # visitor has been idle longer than @visit_ttl_seconds (a late refresh, or reopening
  # the page after a while), we rotate the id. Chat conversations and support tickets
  # are keyed on this id, so rotating it starts them fresh — while quick refreshes
  # within the window keep the same session. Also the rate-limit actor key.
  @visit_ttl_seconds 30 * 60

  defp put_visitor_id(conn, _opts) do
    now = System.system_time(:second)
    id = Plug.Conn.get_session(conn, :visitor_id)
    seen_at = Plug.Conn.get_session(conn, :visitor_seen_at)

    conn =
      if is_binary(id) and is_integer(seen_at) and now - seen_at <= @visit_ttl_seconds do
        conn
      else
        new_id = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
        Plug.Conn.put_session(conn, :visitor_id, new_id)
      end

    Plug.Conn.put_session(conn, :visitor_seen_at, now)
  end

  scope "/", SupportBotWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", ChatLive
    live "/support", TicketLive.Index
    live "/support/:id", TicketLive.Show
    live "/status/:token", StatusLive
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
