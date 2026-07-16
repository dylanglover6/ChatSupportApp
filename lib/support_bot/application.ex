defmodule SupportBot.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SupportBot.Repo,
      {DNSCluster, query: Application.get_env(:support_bot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SupportBot.PubSub},
      SupportBot.RateLimiter,
      SupportBotWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SupportBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SupportBotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
