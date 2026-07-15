defmodule SupportBotWeb.TicketLive.Show do
  use SupportBotWeb, :live_view

  alias SupportBot.Tickets

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    ticket = Tickets.get_ticket!(id)
    {:ok, assign(socket, page_title: ticket.title, ticket: ticket)}
  end

  @impl true
  def handle_event("save_reply", %{"reply" => attrs}, socket) do
    {:ok, _reply} = Tickets.add_reply(socket.assigns.ticket.id, attrs)
    ticket = Tickets.get_ticket!(socket.assigns.ticket.id)

    {:noreply,
     socket
     |> put_flash(:info, "Reply saved.")
     |> assign(:ticket, ticket)}
  end

  def handle_event("generate_agent_assist", _params, socket) do
    ticket = Tickets.generate_agent_assist(socket.assigns.ticket.id)
    {:noreply, assign(socket, :ticket, Tickets.get_ticket!(ticket.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid two">
      <section class="grid">
        <div class="panel">
          <h2>{@ticket.title}</h2>
          <div class="row">
            <.badge kind={String.downcase(@ticket.priority)}>{@ticket.priority}</.badge>
            <.badge>{@ticket.category}</.badge>
            <.badge kind={status_kind(@ticket.status)}>{@ticket.status}</.badge>
            <.badge :if={@ticket.assigned_agent} kind={String.downcase(@ticket.assigned_agent.color)}>
              {@ticket.assigned_agent.name}
            </.badge>
          </div>
          <p><strong>Customer:</strong> {@ticket.customer_name} · {@ticket.customer_email}</p>
          <p class="muted">{@ticket.assignment_reason}</p>
        </div>

        <div class="panel">
          <h2>AI Summary</h2>
          <p><strong>Issue summary:</strong> {@ticket.issue_summary}</p>
          <p><strong>Conversation summary:</strong> {@ticket.conversation_summary}</p>
          <p><strong>Steps tried:</strong> {@ticket.steps_tried}</p>
          <p><strong>Likely cause:</strong> {@ticket.likely_cause}</p>
          <p><strong>Missing information:</strong> {@ticket.missing_information}</p>
          <div class="sources">
            <.link
              :for={source <- @ticket.kb_sources}
              class="badge badge-normal"
              navigate={~p"/docs/#{source["slug"]}"}
            >
              {source["title"]}
            </.link>
          </div>
        </div>

        <div class="panel">
          <h2>Chatbot History</h2>
          <div class="chat-log" style="min-height: 0;">
            <div
              :for={message <- sorted(@ticket.conversation.messages)}
              class={"message #{message.role}"}
            >
              {message.content}
            </div>
          </div>
        </div>
      </section>

      <aside class="grid">
        <section class="panel">
          <h2>Agent Composer</h2>
          <form phx-submit="save_reply">
            <input name="reply[author_name]" value={agent_name(@ticket)} />
            <select name="reply[reply_type]">
              <option value="agent_reply">Customer Reply</option>
              <option value="internal_note">Internal Note</option>
            </select>
            <textarea name="reply[body]" placeholder="Write a reply or internal note..." required></textarea>
            <button class="primary" type="submit">Save Reply</button>
          </form>
          <p class="muted">
            In a production version, customer replies would be emailed to the customer.
          </p>
        </section>

        <section class="panel">
          <h2>AI Agent Assist</h2>
          <button type="button" phx-click="generate_agent_assist">Generate Agent Assist</button>
          <pre :if={@ticket.agent_assist} class="article-body"><%= @ticket.agent_assist %></pre>
        </section>

        <section class="panel">
          <h2>Timeline</h2>
          <div class="timeline">
            <div :for={event <- sorted(@ticket.events)} class="timeline-item">
              <strong>{event.event_type}</strong>
              <p>{event.message}</p>
            </div>
            <div :for={reply <- sorted(@ticket.replies)} class="timeline-item">
              <strong>{label_reply(reply.reply_type)} by {reply.author_name}</strong>
              <p>{reply.body}</p>
            </div>
          </div>
        </section>
      </aside>
    </div>
    """
  end

  defp agent_name(%{assigned_agent: nil}), do: "Support Agent"
  defp agent_name(%{assigned_agent: agent}), do: agent.name
  defp label_reply("agent_reply"), do: "Customer Reply"
  defp label_reply(_), do: "Internal Note"
  defp sorted(items), do: Enum.sort_by(items, & &1.inserted_at, DateTime)
  defp status_kind("Waiting" <> _), do: "waiting"
  defp status_kind(status), do: status |> String.downcase() |> String.replace(" ", "-")
end
