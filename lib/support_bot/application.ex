defmodule SupportBot.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SupportBot.Repo,
      {DNSCluster, query: Application.get_env(:support_bot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SupportBot.PubSub},
      SupportBot.RateLimiter,
      SupportBot.Cleanup,
      SupportBotWeb.Endpoint
    ]

    # The DB-free test env skips the Repo and the DB-querying Cleanup worker so
    # `mix test` needs no Postgres (config/test.exs sets start_repo: false).
    # Flip that flag back to true when a DB-backed test is added.
    children =
      if Application.get_env(:support_bot, :start_repo, true),
        do: children,
        else: children -- [SupportBot.Repo, SupportBot.Cleanup]

    opts = [strategy: :one_for_one, name: SupportBot.Supervisor]

    result = Supervisor.start_link(children, opts)
    SupportBot.AI.Client.log_provider()
    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    SupportBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
