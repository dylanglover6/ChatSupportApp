defmodule SupportBotWeb.StatusLive do
  @moduledoc """
  Visitor-facing, read-only ticket status page reached via a per-ticket capability
  token (`/status/:token`). Shows the current status, who's handling it, and the
  public updates, never internal notes.
  """
  use SupportBotWeb, :live_view

  alias SupportBot.Tickets

  @hidden_events ~w(note_added off_shift_assignment reassigned ticket_assigned)

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    ticket = Tickets.get_ticket_by_token(token)

    {:ok,
     socket
     |> assign(:page_title, "Ticket Status")
     |> assign(:ticket, ticket)
     |> assign(:timeline, timeline(ticket))}
  end

  @impl true
  def render(%{ticket: nil} = assigns) do
    ~H"""
    <div class="status-page">
      <section class="panel">
        <h2>Ticket not found</h2>
        <p class="muted">
          That status link doesn't match a ticket. Double-check the link, or
          <.link navigate={~p"/chat"}>start a new message</.link>
          for Dylan.
        </p>
      </section>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="status-page">
      <section class="panel">
        <div class="section-heading">
          <h2>{@ticket.title}</h2>
          <.badge kind={status_kind(@ticket.status)}>{@ticket.status}</.badge>
        </div>
        <p class="status-lede">{status_description(@ticket.status)}</p>
        <div class="row">
          <span :if={@ticket.urgent} class="badge badge-urgent-pin">URGENT</span>
          <.badge kind="level">L{@ticket.support_level}</.badge>
          <.badge kind={String.downcase(@ticket.priority)}>{@ticket.priority}</.badge>
          <.badge>{@ticket.category}</.badge>
        </div>
        <p class="muted small">
          Opened {age(@ticket.inserted_at)}{if @ticket.assigned_agent,
            do: " · handled by #{@ticket.assigned_agent.name}"}
        </p>
      </section>

      <section class="panel">
        <h2>Updates</h2>
        <div :if={@timeline == []} class="muted">No updates yet. Hang tight.</div>
        <div class="timeline">
          <div :for={item <- @timeline}>{render_item(item)}</div>
        </div>
      </section>

      <p class="status-footer muted small">
        Bookmark this page to check back anytime.
        <.link navigate={~p"/chat"}>Add to the conversation →</.link>
      </p>
    </div>
    """
  end

  defp render_item(%{kind: :event, data: event}) do
    assigns = %{event: event}

    ~H"""
    <div class="timeline-item">
      <strong>{event_label(@event.event_type)}</strong>
      <p>{@event.message}</p>
    </div>
    """
  end

  defp render_item(%{kind: :email, data: reply}) do
    assigns = %{reply: reply}

    ~H"""
    <div class="timeline-email">
      <div class="timeline-email-header">
        <span><strong>Email from {@reply.author_name}</strong></span>
        <span class="badge badge-waiting">SIMULATED: NOT DELIVERED</span>
      </div>
      <p>{@reply.body}</p>
    </div>
    """
  end

  defp render_item(%{kind: :chat, data: reply}) do
    assigns = %{reply: reply}

    ~H"""
    <div class="message agent" style="margin-bottom: 10px;">
      <strong class="muted small">{@reply.author_name} · live chat</strong>
      <p class="message-body">{@reply.body}</p>
    </div>
    """
  end

  defp timeline(nil), do: []

  defp timeline(ticket) do
    events =
      ticket.events
      |> Enum.reject(&(&1.event_type in @hidden_events))
      |> Enum.map(&%{at: &1.inserted_at, kind: :event, data: &1})

    replies =
      ticket.replies
      |> Enum.filter(&(&1.kind in ["email", "chat"]))
      |> Enum.map(&%{at: &1.inserted_at, kind: String.to_atom(&1.kind), data: &1})

    (events ++ replies) |> Enum.sort_by(& &1.at, DateTime)
  end

  defp status_description("New"), do: "Received, waiting to be picked up by the team."
  defp status_description("Open"), do: "In progress. Someone's on it."
  defp status_description("Waiting for Agent"), do: "Queued for the next available agent."
  defp status_description("Resolved"), do: "Resolved. See the updates below."
  defp status_description("Closed"), do: "Closed. Thanks for reaching out!"
  defp status_description(_), do: "We're on it."

  defp event_label("ticket_created"), do: "Created"
  defp event_label("status_changed"), do: "Status update"
  defp event_label("reopened"), do: "Reopened"
  defp event_label("escalated"), do: "Escalated"
  defp event_label("email_sent"), do: "Email sent"
  defp event_label("chat_message"), do: "Live chat"
  defp event_label("agent_takeover"), do: "Agent joined"
  defp event_label("agent_handback"), do: "Back to DylanBot"
  defp event_label(other), do: other |> String.replace("_", " ") |> String.capitalize()

  defp status_kind("Waiting" <> _), do: "waiting"
  defp status_kind(status), do: status |> String.downcase() |> String.replace(" ", "-")

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
