defmodule SupportBotWeb.ConnectThrottle do
  @moduledoc """
  An `on_mount` hook that throttles LiveView socket **connects** per actor, so a
  reconnect storm can't spin up unbounded LiveView processes. Only the connected
  (websocket) mount counts; the dead render is already covered by the router's
  `:request` throttle.

  Over the limit we halt the mount and redirect home; the LiveView process dies
  immediately instead of persisting. The limit is generous (`RateLimiter :connect`),
  so ordinary browsing never trips it.
  """

  import Phoenix.LiveView, only: [connected?: 1, redirect: 2]

  alias SupportBot.RateLimiter
  alias SupportBotWeb.RateLimit

  def on_mount(:default, _params, session, socket) do
    if connected?(socket) and
         match?(
           {:error, :rate_limited, _},
           RateLimiter.check(:connect, RateLimit.actor(socket, session))
         ) do
      {:halt, redirect(socket, to: "/")}
    else
      {:cont, socket}
    end
  end
end
