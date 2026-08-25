import Config

config :support_bot, SupportBot.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "support_bot_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :support_bot, SupportBotWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "test-secret-key-base-for-local-support-bot-only-please-do-not-use-this-value-in-production-2026",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

# DB-free tests: don't start the Repo/Cleanup supervisor children, so `mix test`
# runs without a Postgres. Set to true (and restore the ecto steps in the mix.exs
# `test` alias) once a DB-backed test needs the database.
config :support_bot, start_repo: false
