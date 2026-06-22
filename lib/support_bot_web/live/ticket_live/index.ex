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
    |> assign(:page_title, "Manager Dashboard")
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
            </p>
            <p>Status: <strong>{agent.availability}</strong></p>
            <p>Shift: {Schedule.shift_label(agent)}</p>
            <p>Specialties: {Enum.join(agent.specialties, ", ")}</p>
            <p>Open Tickets: <strong>{agent.open_ticket_count}</strong></p>
          </article>
        </div>
      </section>

      <section class="panel">
        <h2>Open Ticket Queue</h2>
        <table class="table">
          <thead>
            <tr>
              <th>Ticket</th>
              <th>Customer</th>
              <th>Category</th>
              <th>Priority</th>
              <th>Status</th>
              <th>Assigned</th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@tickets == []}>
              <td colspan="6" class="muted">No tickets yet. Create one from the chat page.</td>
            </tr>
            <tr :for={ticket <- @tickets}>
              <td><.link navigate={~p"/tickets/#{ticket.id}"}>{ticket.title}</.link></td>
              <td>{ticket.customer_email}</td>
              <td>
                <.badge>{ticket.category}</.badge>
              </td>
              <td>
                <.badge kind={String.downcase(ticket.priority)}>{ticket.priority}</.badge>
              </td>
              <td>
                <.badge kind={status_kind(ticket.status)}>{ticket.status}</.badge>
              </td>
              <td>
                <span :if={ticket.assigned_agent}>
                  <.badge kind={String.downcase(ticket.assigned_agent.color)}>
                    {ticket.assigned_agent.name}
                  </.badge>
                </span>
              </td>
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
end
