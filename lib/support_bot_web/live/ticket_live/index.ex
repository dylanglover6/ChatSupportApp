defmodule SupportBotWeb.TicketLive.Index do
  use SupportBotWeb, :live_view

  alias SupportBot.{Agents, Tickets}
  alias SupportBot.Agents.Schedule

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  defp load(socket) do
    socket
    |> assign(:page_title, "DylanSupport")
    |> assign(:agents, Agents.list_agents())
    |> assign(:tickets, Tickets.list_tickets())
    |> assign(:events, Tickets.recent_events())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid">
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
          </article>
        </div>
      </section>

      <section class="panel">
        <h2>Ticket Queue</h2>
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
                  <span class="expertise-dots small">{expertise_dots(ticket.assigned_agent.expertise_level)}</span>
                </span>
              </td>
              <td data-label="Age" class="muted">{age(ticket.inserted_at)}</td>
            </tr>
          </tbody>
        </table>
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
