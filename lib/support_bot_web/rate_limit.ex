defmodule SupportBotWeb.RateLimit do
  @moduledoc """
  Helpers for deriving a rate-limit "actor" from a LiveView socket + session and
  applying `SupportBot.RateLimiter` inside LiveView event handlers.
  """

  import Phoenix.LiveView, only: [get_connect_info: 2]

  alias SupportBot.RateLimiter

  @doc """
  Builds a stable actor key for the current visitor: their session `visitor_id`
  combined with a best-effort client IP (the first `x-forwarded-for` entry when
  behind a reverse proxy, otherwise the socket peer address). Falling back to the
  session id alone still throttles per-browser if no IP is available.
  """
  def actor(socket, session) do
    "#{visitor_id(session)}|#{client_ip(socket)}"
  end

  @doc "The stable per-session visitor id (stamped by the router's `put_visitor_id` plug)."
  def visitor_id(session) do
    Map.get(session, "visitor_id") || Map.get(session, :visitor_id) || "anon"
  end

  @doc "Registers a hit for `action`; see `SupportBot.RateLimiter.check/2`."
  def check(action, actor), do: RateLimiter.check(action, actor)

  defp client_ip(socket) do
    with headers when is_list(headers) <- get_connect_info(socket, :x_headers),
         {_, forwarded} <- List.keyfind(headers, "x-forwarded-for", 0),
         [first | _] <- String.split(forwarded, ",") do
      String.trim(first)
    else
      _ ->
        case get_connect_info(socket, :peer_data) do
          %{address: address} -> address |> :inet.ntoa() |> to_string()
          _ -> "noip"
        end
    end
  end
end
