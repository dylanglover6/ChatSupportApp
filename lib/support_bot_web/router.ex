defmodule SupportBotWeb.Router do
  use SupportBotWeb, :router

  alias SupportBot.RateLimiter

  pipeline :browser do
    plug :accepts, ["html"]
    plug :throttle_request
    plug :fetch_session
    plug :put_visitor_id
    plug :fetch_live_flash
    plug :put_root_layout, html: {SupportBotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp
  end

  # A cheap per-IP throttle on raw page/asset loads; the app-level chat/ticket
  # limiters don't cover crawlers or a small flood hammering HTML routes. Generous
  # (see RateLimiter :request); over it we 429 without touching the session or DB.
  defp throttle_request(conn, _opts) do
    case RateLimiter.check(:request, client_ip(conn)) do
      :ok ->
        conn

      {:error, :rate_limited, retry_after} ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", Integer.to_string(retry_after))
        |> Plug.Conn.send_resp(429, "Too many requests. Slow down and try again shortly.")
        |> Plug.Conn.halt()
    end
  end

  # Content-Security-Policy with a per-request nonce for our two inline scripts
  # (nav pre-paint in root.html.heex, hero subline in home.html.heex), so we can
  # drop 'unsafe-inline' for scripts. All other resources are same-origin; the
  # LiveView socket needs ws:/wss: in connect-src. `@csp_nonce` is read by the
  # templates.
  defp put_csp(conn, _opts) do
    nonce = 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    csp =
      Enum.join(
        [
          "default-src 'self'",
          "script-src 'self' 'nonce-#{nonce}'",
          "style-src 'self' 'unsafe-inline'",
          "img-src 'self' data:",
          "font-src 'self'",
          "connect-src 'self' ws: wss:",
          "base-uri 'self'",
          "form-action 'self'",
          "frame-ancestors 'none'",
          "object-src 'none'"
        ],
        "; "
      )

    conn
    |> Plug.Conn.assign(:csp_nonce, nonce)
    |> Plug.Conn.put_resp_header("content-security-policy", csp)
  end

  # Best-effort client IP: first x-forwarded-for entry when behind Caddy, else the
  # socket peer. Mirrors SupportBotWeb.RateLimit.actor/2 for the LiveView side.
  defp client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      [] ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  # A visit "session" handle: a random visitor id plus a rolling last-seen timestamp,
  # both in the signed session cookie. On every request we refresh last-seen; if the
  # visitor has been idle longer than @visit_ttl_seconds (a late refresh, or reopening
  # the page after a while), we rotate the id. Chat conversations and support tickets
  # are keyed on this id, so rotating it starts them fresh, while quick refreshes
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

    # Legacy paths: permanent redirects to the renamed routes.
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
