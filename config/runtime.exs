import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is missing"

  config :support_bot, SupportBot.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is missing"

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :support_bot, SupportBotWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true,
    # Only accept LiveView/WebSocket connects from our own hosts (apex + www), so
    # other origins can't open sockets against the app. See plans/04-PLAN-security.md §2.
    check_origin: ["https://#{host}", "https://www.#{host}"],
    # Redirect http→https behind Caddy and emit HSTS (Plug.SSL defaults to a 1-year
    # max-age); Caddy already terminates TLS. See plans/04-PLAN-security.md §4.
    force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: true]
end
