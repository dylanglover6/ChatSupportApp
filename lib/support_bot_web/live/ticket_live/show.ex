defmodule SupportBotWeb.TicketLive.Show do
  use SupportBotWeb, :live_view

  alias SupportBot.{Agents, Chat, Tickets}
  alias SupportBotWeb.RateLimit

  @impl true
  def mount(%{"id" => id}, session, socket) do
    visitor_id = RateLimit.visitor_id(session)
    Tickets.ensure_visitor_tickets(visitor_id)

    case Tickets.get_visible_ticket(id, visitor_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That ticket isn't available on your DylanSupport desk.")
         |> push_navigate(to: ~p"/support")}

      _visible ->
        ticket = Tickets.open_ticket(id)
        if connected?(socket), do: Chat.subscribe(ticket.conversation_id)

        {:ok,
         socket
         |> assign(:page_title, ticket.title)
         |> assign(:ticket, ticket)
         |> assign(:agents, Agents.list_agents())
         |> assign(:agent_active, ticket.conversation.agent_active)
         |> assign(:active_agent_name, ticket.conversation.active_agent_name)
         |> assign(:show_email_form, false)
         |> assign(:chat_draft, "")}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    ticket = socket.assigns.ticket
    conversation = ticket.conversation

    if message.conversation_id == conversation.id and
         message.id not in Enum.map(conversation.messages, & &1.id) do
      updated = %{
        ticket
        | conversation: %{conversation | messages: conversation.messages ++ [message]}
      }

      {:noreply, assign(socket, :ticket, updated)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:agent_status, active?, agent_name}, socket) do
    {:noreply,
     socket
     |> assign(:agent_active, active?)
     |> assign(:active_agent_name, agent_name)}
  end

  @impl true
  def handle_event("resolve", _params, socket) do
    {:noreply, reload(socket, Tickets.resolve_ticket(socket.assigns.ticket.id))}
  end

  def handle_event("close", _params, socket) do
    {:noreply, reload(socket, Tickets.close_ticket(socket.assigns.ticket.id))}
  end

  def handle_event("reopen", _params, socket) do
    {:noreply, reload(socket, Tickets.reopen_ticket(socket.assigns.ticket.id))}
  end

  def handle_event("escalate", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Ticket escalated to a level 3 agent.")
     |> reload(Tickets.escalate_ticket(socket.assigns.ticket.id))}
  end

  def handle_event("reassign", %{"agent_id" => agent_id}, socket) do
    {:noreply, reload(socket, Tickets.reassign_ticket(socket.assigns.ticket.id, agent_id))}
  end

  def handle_event("save_reply", %{"reply" => attrs}, socket) do
    attrs = Map.put(attrs, "kind", "note")
    {:ok, _reply} = Tickets.add_reply(socket.assigns.ticket.id, attrs)

    {:noreply,
     socket
     |> put_flash(:info, "Internal note saved.")
     |> reload(Tickets.get_ticket!(socket.assigns.ticket.id))}
  end

  def handle_event("show_email_form", _params, socket) do
    {:noreply, assign(socket, :show_email_form, true)}
  end

  def handle_event("hide_email_form", _params, socket) do
    {:noreply, assign(socket, :show_email_form, false)}
  end

  def handle_event("send_email", %{"email" => attrs}, socket) do
    ticket = socket.assigns.ticket

    reply_attrs = %{
      "kind" => "email",
      "author_name" => agent_name(ticket),
      "body" => attrs["body"],
      "email_to" => attrs["to"],
      "email_subject" => attrs["subject"]
    }

    {:ok, _reply} = Tickets.add_reply(ticket.id, reply_attrs)

    {:noreply,
     socket
     |> put_flash(:info, "Simulated email sent, not actually delivered.")
     |> assign(:show_email_form, false)
     |> reload(Tickets.get_ticket!(ticket.id))}
  end

  def handle_event("take_over", _params, socket) do
    {:noreply, reload(socket, Tickets.take_over_chat(socket.assigns.ticket.id))}
  end

  def handle_event("hand_back", _params, socket) do
    {:noreply, reload(socket, Tickets.hand_back_chat(socket.assigns.ticket.id))}
  end

  def handle_event("update_chat_draft", %{"message" => message}, socket) do
    {:noreply, assign(socket, :chat_draft, message)}
  end

  def handle_event("send_agent_chat", %{"message" => message}, socket) do
    message = String.trim(message)
    ticket = socket.assigns.ticket

    if message != "" do
      {:ok, _reply} =
        Tickets.add_reply(ticket.id, %{
          "kind" => "chat",
          "author_name" => agent_name(ticket),
          "body" => message
        })

      {:noreply, socket |> assign(:chat_draft, "") |> reload(Tickets.get_ticket!(ticket.id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("generate_agent_assist", _params, socket) do
    ticket = Tickets.generate_agent_assist(socket.assigns.ticket.id)
    {:noreply, reload(socket, Tickets.get_ticket!(ticket.id))}
  end

  defp reload(socket, ticket) do
    socket
    |> assign(:ticket, ticket)
    |> assign(:agent_active, ticket.conversation.agent_active)
    |> assign(:active_agent_name, ticket.conversation.active_agent_name)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid two">
      <section class="grid">
        <div class="panel">
          <div class="section-heading">
            <h2>{@ticket.title}</h2>
            <div class="header-actions">
              <button
                :if={@ticket.status not in ["Resolved", "Closed"]}
                type="button"
                class="mini-button success"
                phx-click="resolve"
              >Resolve</button>
              <button
                :if={@ticket.status == "Resolved"}
                type="button"
                class="mini-button"
                phx-click="close"
              >Close</button>
              <button
                :if={@ticket.status in ["Resolved", "Closed"]}
                type="button"
                class="mini-button"
                phx-click="reopen"
              >Reopen</button>
              <button
                :if={@ticket.status != "Closed"}
                type="button"
                class="mini-button danger"
                phx-click="escalate"
              >Escalate</button>
            </div>
          </div>
          <div class="row">
            <span :if={@ticket.urgent} class="badge badge-urgent-pin">URGENT</span>
            <.badge kind="level">L{@ticket.support_level}</.badge>
            <.badge kind={String.downcase(@ticket.priority)}>{@ticket.priority}</.badge>
            <.badge>{@ticket.category}</.badge>
            <.badge kind={status_kind(@ticket.status)}>{@ticket.status}</.badge>
          </div>
          <p><strong>Customer:</strong> {@ticket.customer_name} · {@ticket.customer_email}</p>
          <p class="muted">{@ticket.assignment_reason}</p>
          <form phx-change="reassign" class="row">
            <label for="reassign-agent">Reassign to:</label>
            <select id="reassign-agent" name="agent_id">
              <option
                :for={agent <- @agents}
                value={agent.id}
                selected={@ticket.assigned_agent && agent.id == @ticket.assigned_agent.id}
              >
                {agent.name} (L{agent.expertise_level})
              </option>
            </select>
          </form>
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
          <h2>Full History</h2>
          <div class="timeline">
            <div :for={entry <- timeline_entries(@ticket)}>
              {render_entry(entry)}
            </div>
          </div>
        </div>
      </section>

      <aside class="grid">
        <section class="panel">
          <h2>Live Chat Takeover</h2>
          <p :if={not @agent_active} class="muted">
            Take over to respond in real time in the visitor's chat widget. DylanBot pauses while you're active.
          </p>
          <button :if={not @agent_active} type="button" class="primary" phx-click="take_over">Take Over Chat</button>

          <div :if={@agent_active}>
            <p class="widget-escalated">{@active_agent_name} is live in this chat.</p>
            <div
              id="ticket-chat-log"
              class="chat-log"
              style="min-height: 160px;"
              phx-hook="AutoScroll"
            >
              <div
                :for={
                  message <- Enum.sort_by(@ticket.conversation.messages, & &1.inserted_at, DateTime)
                }
                class={"message #{message.role}"}
              >
                <span class="message-body" phx-no-format>{message.content}</span>
              </div>
            </div>
            <form phx-submit="send_agent_chat" class="widget-input-row">
              <input
                name="message"
                value={@chat_draft}
                placeholder="Type a live reply..."
                aria-label="Live reply"
                autocomplete="off"
              />
              <button type="submit">Send</button>
            </form>
            <button type="button" phx-click="hand_back">Hand Back to Bot</button>
          </div>
        </section>

        <section class="panel">
          <h2>Agent Composer</h2>
          <form phx-submit="save_reply">
            <input name="reply[author_name]" value={agent_name(@ticket)} aria-label="Author name" />
            <textarea
              name="reply[body]"
              placeholder="Write an internal note..."
              aria-label="Internal note"
              required
            ></textarea>
            <button class="primary" type="submit">Save Internal Note</button>
          </form>
          <button type="button" phx-click="show_email_form">Send Email (Simulated)</button>
          <p class="muted">
            No real email is ever sent. This writes a simulated, clearly-labeled timeline entry.
          </p>
        </section>

        <section class="panel">
          <h2>AI Agent Assist</h2>
          <button type="button" phx-click="generate_agent_assist">Generate Agent Assist</button>
          <pre :if={@ticket.agent_assist} class="article-body"><%= @ticket.agent_assist %></pre>
        </section>
      </aside>

      <div
        :if={@show_email_form}
        class="modal-backdrop"
        phx-window-keydown="hide_email_form"
        phx-key="Escape"
      >
        <section class="modal" phx-click-away="hide_email_form">
          <div class="section-heading">
            <h2>Send Email (Simulated)</h2>
            <button type="button" class="icon-button" phx-click="hide_email_form">Close</button>
          </div>
          <form phx-submit="send_email">
            <input
              name="email[to]"
              value={@ticket.customer_email}
              placeholder="To"
              aria-label="To"
              required
            />
            <input
              name="email[subject]"
              value={"Re: #{@ticket.title}"}
              placeholder="Subject"
              aria-label="Subject"
              required
            />
            <textarea name="email[body]" placeholder="Email body..." aria-label="Email body" required></textarea>
            <button class="primary" type="submit">Send Simulated Email</button>
          </form>
        </section>
      </div>
    </div>
    """
  end

  defp agent_name(%{assigned_agent: nil}), do: "Support Agent"
  defp agent_name(%{assigned_agent: agent}), do: agent.name
  defp status_kind("Waiting" <> _), do: "waiting"
  defp status_kind(status), do: status |> String.downcase() |> String.replace(" ", "-")

  defp timeline_entries(ticket) do
    messages =
      ticket.conversation.messages
      |> Enum.reject(&(&1.role == "agent"))
      |> Enum.map(&%{at: &1.inserted_at, kind: :message, data: &1})

    events = Enum.map(ticket.events, &%{at: &1.inserted_at, kind: :event, data: &1})
    replies = Enum.map(ticket.replies, &%{at: &1.inserted_at, kind: :reply, data: &1})

    (messages ++ events ++ replies)
    |> Enum.sort_by(& &1.at, DateTime)
  end

  defp render_entry(%{kind: :message, data: message}) do
    assigns = %{message: message}

    ~H"""
    <div class={"message #{@message.role}"} style="margin-bottom: 10px;">
      <strong class="muted small">{String.capitalize(@message.role)}</strong>
      <p class="message-body">{@message.content}</p>
    </div>
    """
  end

  defp render_entry(%{kind: :event, data: event}) do
    assigns = %{event: event}

    ~H"""
    <div class="timeline-item">
      <strong>{@event.event_type}</strong>
      <p>{@event.message}</p>
    </div>
    """
  end

  defp render_entry(%{kind: :reply, data: %{kind: "note"} = reply}) do
    assigns = %{reply: reply}

    ~H"""
    <div class="timeline-note">
      <strong>Internal Note by {@reply.author_name}</strong>
      <p>{@reply.body}</p>
    </div>
    """
  end

  defp render_entry(%{kind: :reply, data: %{kind: "email"} = reply}) do
    assigns = %{reply: reply}

    ~H"""
    <div class="timeline-email">
      <div class="timeline-email-header">
        <span><strong>To:</strong> {@reply.email_to}</span>
        <span><strong>Subject:</strong> {@reply.email_subject}</span>
        <span class="badge badge-waiting">SIMULATED: NOT DELIVERED</span>
      </div>
      <p>{@reply.body}</p>
    </div>
    """
  end

  defp render_entry(%{kind: :reply, data: %{kind: "chat"} = reply}) do
    assigns = %{reply: reply}

    ~H"""
    <div class="message agent" style="margin-bottom: 10px;">
      <strong class="muted small">Live chat · {@reply.author_name}</strong>
      <p class="message-body">{@reply.body}</p>
    </div>
    """
  end
end
