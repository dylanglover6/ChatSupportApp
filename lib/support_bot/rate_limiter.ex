defmodule SupportBot.RateLimiter do
  @moduledoc """
  A tiny in-memory, fixed-window rate limiter backed by ETS.

  Keeps the portfolio's public surfaces (the chat bot, ticket creation) from being
  spammed or brute-forced without adding an external dependency. Limits are per
  "actor" (a visitor id + best-effort client IP) per named action.

  Not a distributed limiter — one node, in-memory, resets on restart. That's the right
  fit for a single-VM portfolio deploy; revisit if this ever runs multi-node.
  """

  use GenServer

  @table __MODULE__

  # {action, limit (max hits), window in ms}
  @limits %{
    chat: {12, 30_000},
    ticket: {5, 600_000},
    # Cost containment for the paid Claude API: a per-actor daily cap on live model
    # calls, plus a single global daily ceiling that backstops the monthly bill even
    # under a distributed flood. Over either limit, `AI.Client.chat/4` degrades to the
    # deterministic fallback instead of billing a request.
    llm_daily: {100, 86_400_000},
    llm_global: {2_000, 86_400_000},
    # Connection-level throttles, keyed on client IP / actor. `request` guards raw
    # HTML/asset page loads through the browser pipeline; `connect` guards LiveView
    # socket mounts so a reconnect storm can't spin up unbounded processes. Both
    # generous — a human never hits them.
    request: {300, 60_000},
    connect: {60, 60_000}
  }

  @global_actor "__global__"

  def global_actor, do: @global_actor

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a hit for `actor` against `action`. Returns `:ok` while under the limit,
  or `{:error, :rate_limited, retry_after_seconds}` once the window's budget is spent.
  """
  @spec check(atom(), String.t()) :: :ok | {:error, :rate_limited, non_neg_integer()}
  def check(action, actor) when is_atom(action) and is_binary(actor) do
    {limit, window_ms} = Map.fetch!(@limits, action)
    now = System.system_time(:millisecond)
    window = div(now, window_ms)
    key = {action, actor, window}

    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

    if count > limit do
      retry_after = div((window + 1) * window_ms - now, 1000) + 1
      {:error, :rate_limited, retry_after}
    else
      :ok
    end
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    # Drop counters from windows that are safely in the past for every action.
    max_window_ms = @limits |> Map.values() |> Enum.map(&elem(&1, 1)) |> Enum.max()
    cutoff = div(System.system_time(:millisecond) - 2 * max_window_ms, 1)

    :ets.foldl(
      fn {{action, _actor, window}, _count} = obj, acc ->
        {_limit, window_ms} = Map.fetch!(@limits, action)
        if window * window_ms < cutoff, do: :ets.delete_object(@table, obj)
        acc
      end,
      :ok,
      @table
    )

    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, 5 * 60_000)
  end
end
