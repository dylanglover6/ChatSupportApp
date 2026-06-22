import Config

config :support_bot,
  ecto_repos: [SupportBot.Repo],
  generators: [timestamp_type: :utc_datetime]

config :support_bot, SupportBotWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: SupportBotWeb.ErrorHTML, json: SupportBotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SupportBot.PubSub,
  live_view: [signing_salt: "supportbot"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.25.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

import_config "#{config_env()}.exs"
