defmodule SupportBotWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :support_bot

  # `secure` is set only in prod (the dev server is plain http, where a secure-only
  # cookie would never be sent). `http_only` + `same_site: Lax` apply everywhere.
  @session_options [
    store: :cookie,
    key: "_support_bot_key",
    signing_salt: "supportbot",
    http_only: true,
    same_site: "Lax",
    secure: Mix.env() == :prod
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:peer_data, :x_headers, session: @session_options]],
    longpoll: [connect_info: [:peer_data, :x_headers, session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :support_bot,
    gzip: false,
    only: SupportBotWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  # Liveness probe for uptime monitoring. Answered here, before the session/router
  # pipeline, so a monitor's polling never touches the DB, session, or rate limiter.
  plug :health_check

  defp health_check(%Plug.Conn{request_path: "/up"} = conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "ok")
    |> Plug.Conn.halt()
  end

  defp health_check(conn, _opts), do: conn

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug SupportBotWeb.Router
end
