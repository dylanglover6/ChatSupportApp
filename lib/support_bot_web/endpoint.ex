defmodule SupportBotWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :support_bot

  # `secure` is set only in prod (the dev server is plain http, where a secure-only
  # cookie would never be sent). `http_only` + `same_site: Lax` apply everywhere.
  # See plans/04-PLAN-security.md, Pass 4.
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
