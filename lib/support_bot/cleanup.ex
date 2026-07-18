defmodule SupportBot.Cleanup do
  @moduledoc """
  Periodically prunes stale, visitor-created conversations and tickets so the demo
  database doesn't accumulate cruft as visit sessions rotate (see the visitor-id
  rotation in `SupportBotWeb.Router`).

  Only rows with a non-nil `visitor_id` — i.e. real visitors — and an `updated_at`
  older than the retention window are removed. The seeded demo data
  (`create_conversation/1` and its tickets are inserted with `visitor_id: nil`) is
  never touched, so the `/support` desk stays populated. Deletes cascade to messages,
  ticket events, and ticket replies via the schema's `on_delete` rules; a conversation
  is only removed once no ticket still references it, so a live ticket never loses its
  linked chat history.
  """
  use GenServer

  import Ecto.Query

  alias SupportBot.Chat.Conversation
  alias SupportBot.Repo
  alias SupportBot.Tickets.Ticket

  # How often the sweep runs, and how long a visitor's rows are kept after last activity.
  @sweep_interval :timer.hours(1)
  @retention_hours 24

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    # Run once shortly after boot, then on the interval.
    {:ok, %{}, {:continue, :sweep}}
  end

  @impl true
  def handle_continue(:sweep, state) do
    sweep()
    schedule()
    {:noreply, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule()
    {:noreply, state}
  end

  defp schedule, do: Process.send_after(self(), :sweep, @sweep_interval)

  defp sweep do
    counts = purge()

    if counts.tickets > 0 or counts.conversations > 0 do
      require Logger

      Logger.info(
        "SupportBot.Cleanup pruned #{counts.tickets} ticket(s) and " <>
          "#{counts.conversations} conversation(s)"
      )
    end

    counts
  end

  @doc """
  Deletes visitor-created tickets and conversations untouched for `hours` hours
  (default #{@retention_hours}). Returns `%{tickets: n, conversations: n}`. Exposed so it
  can be run on demand from IEx or tests.
  """
  def purge(hours \\ @retention_hours) do
    cutoff = DateTime.add(DateTime.utc_now(), -hours * 3600, :second)

    {tickets, _} =
      Ticket
      |> where([t], not is_nil(t.visitor_id) and t.updated_at < ^cutoff)
      |> Repo.delete_all()

    conversation_ids_with_tickets =
      from t in Ticket, where: not is_nil(t.conversation_id), select: t.conversation_id

    {conversations, _} =
      Conversation
      |> where([c], not is_nil(c.visitor_id) and c.updated_at < ^cutoff)
      |> where([c], c.id not in subquery(conversation_ids_with_tickets))
      |> Repo.delete_all()

    %{tickets: tickets, conversations: conversations}
  end
end
