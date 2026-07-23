defmodule SupportBotWeb.TicketLive.Index do
  use SupportBotWeb, :live_view

  alias SupportBot.{Agents, Tickets}
  alias SupportBot.Agents.Schedule
  alias SupportBotWeb.RateLimit

  @impl true
  def mount(_params, session, socket) do
    visitor_id = RateLimit.visitor_id(session)
    Tickets.ensure_visitor_tickets(visitor_id)
    {:ok, load(assign(socket, :visitor_id, visitor_id))}
  end

  defp load(socket) do
    visitor_id = socket.assigns.visitor_id
    agents = Agents.list_agents()
    tickets = Tickets.list_tickets(visitor_id)

    socket
    |> assign(:page_title, "DylanSupport")
    |> assign(:agents, agents)
    |> assign(:tickets, tickets)
    |> assign(:events, Tickets.recent_events(visitor_id))
    |> assign(:stats, desk_stats(tickets))
    |> assign(:max_open, max_open(agents))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid">
      <section class="panel">
        <h2>Desk Overview</h2>
        <div class="stat-row">
          <div class="stat-tile">
            <span class="stat-num">{@stats.open}</span>
            <span class="stat-label">Open</span>
          </div>
          <div class={["stat-tile", @stats.urgent > 0 && "stat-danger"]}>
            <span class="stat-num">{@stats.urgent}</span>
            <span class="stat-label">Urgent</span>
          </div>
          <div class="stat-tile">
            <span class="stat-num">{@stats.waiting}</span>
            <span class="stat-label">Waiting</span>
          </div>
          <div class="stat-tile">
            <span class="stat-num">{@stats.resolved}</span>
            <span class="stat-label">Resolved</span>
          </div>
        </div>
      </section>

      <section class="panel">
        <h2>Agent Overview</h2>
        <div class="grid three">
          <article :for={agent <- @agents} class="card">
            <h3>{agent.name}</h3>
            <p>
              <.badge kind={String.downcase(agent.color)}>{agent.color}</.badge>
              <span class="expertise-dots" title={"Level #{agent.expertise_level}"}>
                {expertise_dots(agent.expertise_level)}
              </span>
            </p>
            <p>Status: <strong>{agent.availability}</strong></p>
            <p>Shift: {Schedule.shift_label(agent)}</p>
            <p>Specialties: {Enum.join(agent.specialties, ", ")}</p>
            <p>Open Tickets: <strong>{agent.open_ticket_count}</strong></p>
            <div
              class="workload-meter"
              role="img"
              aria-label={"Workload: #{agent.open_ticket_count} open tickets"}
            >
              <span
                class="workload-fill"
                style={"width: #{workload_pct(agent.open_ticket_count, @max_open)}%"}
              ></span>
            </div>
          </article>
        </div>
      </section>

      <section class="panel">
        <h2>Ticket Queue</h2>
        <div class="table-scroll">
        <table class="table">
          <thead>
            <tr>
              <th>Ticket</th>
              <th>Customer</th>
              <th>Category</th>
              <th>Level</th>
              <th>Priority</th>
              <th>Status</th>
              <th>Assigned</th>
              <th>Age</th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@tickets == []}>
              <td colspan="8" class="muted">No tickets yet. Create one from the chat widget.</td>
            </tr>
            <tr :for={ticket <- @tickets} class={ticket.urgent && "is-urgent-row"}>
              <td data-label="Ticket">
                <span :if={ticket.urgent} class="badge badge-urgent-pin">URGENT</span>
                <.link navigate={~p"/support/#{ticket.id}"}>{ticket.title}</.link>
              </td>
              <td data-label="Customer">{ticket.customer_email}</td>
              <td data-label="Category">
                <.badge>{ticket.category}</.badge>
              </td>
              <td data-label="Level">
                <.badge kind="level">L{ticket.support_level}</.badge>
              </td>
              <td data-label="Priority">
                <.badge kind={String.downcase(ticket.priority)}>{ticket.priority}</.badge>
              </td>
              <td data-label="Status">
                <.badge kind={status_kind(ticket.status)}>{ticket.status}</.badge>
              </td>
              <td data-label="Assigned">
                <span :if={ticket.assigned_agent} class="agent-chip">
                  <.badge kind={String.downcase(ticket.assigned_agent.color)}>
                    {ticket.assigned_agent.name}
                  </.badge>
                  <span class="expertise-dots small">{expertise_dots(
                    ticket.assigned_agent.expertise_level
                  )}</span>
                </span>
              </td>
              <td data-label="Age" class={["muted", sla_class(ticket)]}>
                {age(ticket.inserted_at)}
              </td>
            </tr>
          </tbody>
        </table>
        </div>
      </section>

      <section class="panel">
        <h2>Recent Activity</h2>
        <div class="timeline">
          <p :if={@events == []} class="muted">Activity appears after ticket creation and replies.</p>
          <div :for={event <- @events} class="timeline-item">
            <strong>{event.event_type}</strong>
            <p>{event.message}</p>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp status_kind("Waiting" <> _), do: "waiting"
  defp status_kind(status), do: status |> String.downcase() |> String.replace(" ", "-")

  defp expertise_dots(level) do
    String.duplicate("■", level) <> String.duplicate("□", 3 - level)
  end

  defp desk_stats(tickets) do
    active = Enum.reject(tickets, &(&1.status in ["Resolved", "Closed"]))

    %{
      open: length(active),
      urgent: Enum.count(active, & &1.urgent),
      waiting: Enum.count(tickets, &(&1.status == "Waiting for Agent")),
      resolved: Enum.count(tickets, &(&1.status == "Resolved"))
    }
  end

  defp max_open(agents), do: agents |> Enum.map(& &1.open_ticket_count) |> Enum.max(fn -> 0 end)

  defp workload_pct(_count, 0), do: 0
  defp workload_pct(count, max), do: round(count / max * 100)

  # SLA staleness colors the age cell for still-open tickets; done tickets stay neutral.
  defp sla_class(%{status: status}) when status in ["Resolved", "Closed"], do: "sla-done"

  defp sla_class(ticket) do
    hours = DateTime.diff(DateTime.utc_now(), ticket.inserted_at) / 3600

    cond do
      hours < 4 -> "sla-fresh"
      hours < 24 -> "sla-aging"
      true -> "sla-stale"
    end
  end

  defp age(inserted_at) do
    seconds = DateTime.diff(DateTime.utc_now(), inserted_at)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3600)}h ago"
      true -> "#{div(seconds, 86_400)}d ago"
    end
  end
end
