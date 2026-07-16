defmodule SupportBotWeb.ChatLive do
  use SupportBotWeb, :live_view

  alias SupportBot.{AI.Client, AI.DocLinks, Chat, Tickets}
  alias SupportBot.KB.Search

  @impl true
  def mount(_params, _session, socket) do
    conversation = Chat.latest_or_create_conversation("Support chat")
    messages = Chat.list_messages(conversation.id)

    if connected?(socket), do: Chat.subscribe(conversation.id)

    socket =
      socket
      |> assign(:page_title, "Chat")
      |> assign(:conversation, conversation)
      |> assign(:messages, messages)
      |> assign(:sources, sources_from_messages(messages))
      |> assign(:message, "")
      |> assign(:loading, false)
      |> assign(:show_ticket_form, false)
      |> assign(:created_ticket, nil)
      |> assign(:agent_active, conversation.agent_active)
      |> assign(:active_agent_name, conversation.active_agent_name)

    {:ok, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.conversation_id == socket.assigns.conversation.id and
         message.id not in Enum.map(socket.assigns.messages, & &1.id) do
      {:noreply, assign(socket, :messages, socket.assigns.messages ++ [message])}
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
  def handle_event("send", %{"message" => message}, socket) do
    message = String.trim(message)

    if message == "" do
      {:noreply, socket}
    else
      conversation_id = socket.assigns.conversation.id
      user = Chat.add_message(conversation_id, "user", message)
      Tickets.maybe_reopen_for_conversation(conversation_id)

      if socket.assigns.agent_active do
        {:noreply,
         socket
         |> assign(:messages, socket.assigns.messages ++ [user])
         |> assign(:message, "")
         |> assign(:show_ticket_form, false)}
      else
        snippets = Search.search(message)
        sources = to_source_maps(snippets)
        history = Chat.list_messages(conversation_id)
        {response, _status} = Client.chat(message, history, snippets, "/chat")
        assistant = Chat.add_message(conversation_id, "assistant", response, sources)

        {:noreply,
         socket
         |> assign(:messages, socket.assigns.messages ++ [user, assistant])
         |> assign(:sources, merge_sources(socket.assigns.sources, sources))
         |> assign(:message, "")
         |> assign(:show_ticket_form, false)}
      end
    end
  end

  def handle_event("show_ticket_form", _params, socket) do
    {:noreply, assign(socket, :show_ticket_form, true)}
  end

  def handle_event("hide_ticket_form", _params, socket) do
    {:noreply, assign(socket, :show_ticket_form, false)}
  end

  def handle_event("issue_solved", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Great, marked as solved.")
     |> assign(:show_ticket_form, false)}
  end

  def handle_event("new_chat", _params, socket) do
    conversation = Chat.create_conversation("Support chat")

    {:noreply,
     socket
     |> assign(:conversation, conversation)
     |> assign(:messages, [])
     |> assign(:sources, [])
     |> assign(:message, "")
     |> assign(:show_ticket_form, false)
     |> assign(:created_ticket, nil)}
  end

  def handle_event("create_ticket", %{"ticket" => attrs}, socket) do
    sources = socket.assigns.sources

    case Tickets.create_from_conversation(socket.assigns.conversation.id, attrs, sources) do
      {:ok, ticket} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ticket created and assigned.")
         |> assign(:created_ticket, SupportBot.Tickets.get_ticket!(ticket.id))
         |> assign(:show_ticket_form, false)}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :info, "Ticket could not be created: #{inspect(changeset.errors)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-page">
      <section class="panel chat-panel">
        <div class="section-heading">
          <h2>{if @agent_active, do: "Live chat with #{@active_agent_name}", else: "Chat with DylanBot"}</h2>
          <div class="header-actions">
            <button type="button" phx-click="show_ticket_form">Leave a Message for Dylan</button>
            <button type="button" phx-click="new_chat">New Chat</button>
          </div>
        </div>
        <p :if={@agent_active} class="widget-escalated">
          {@active_agent_name} has joined this chat — DylanBot is paused.
        </p>
        <div id="chat-log" class="chat-log" phx-hook="AutoScroll">
          <div :if={@messages == []} class="message assistant">
            Howdy! Ask me about Dylan's skills, projects, or how this platform is built —
            or just say hi and I'll take it from there.
          </div>
          <div :for={message <- @messages} class={"message #{message.role}"}>
            {if message.role == "assistant", do: DocLinks.render(message.content), else: message.content}
            <div :if={message.sources != []} class="sources">
              <.link
                :for={source <- message.sources}
                class="source-link"
                navigate={~p"/docs/#{source["slug"]}"}
              >{source["title"]}</.link>
            </div>
            <div :if={message.role == "assistant"} class="chat-actions">
              <button type="button" class="mini-button success" phx-click="issue_solved">This solved my issue</button>
              <button type="button" class="mini-button danger" phx-click="show_ticket_form">I'm still having problems</button>
            </div>
          </div>
        </div>

        <form phx-submit="send" class="chat-form">
          <input
            name="message"
            value={@message}
            placeholder={if @agent_active, do: "Message #{@active_agent_name}...", else: "Ask DylanBot something..."}
            aria-label="Message"
            autocomplete="off"
          />
          <button class="primary" type="submit">Send</button>
        </form>
      </section>

      <section :if={@created_ticket} class="panel ticket-confirmation">
        <h2>Ticket Created</h2>
        <p><strong>{@created_ticket.title}</strong></p>
        <p>We will follow up at: {@created_ticket.customer_email}</p>
        <p>
          Assigned Agent:
          <.badge kind={String.downcase(@created_ticket.assigned_agent.color)}>
            {@created_ticket.assigned_agent.name}
          </.badge>
        </p>
        <p class="muted">{@created_ticket.assignment_reason}</p>
        <p class="muted">
          In a production version, a confirmation summary would be emailed to the customer.
        </p>
        <.link class="button primary" navigate={~p"/support/#{@created_ticket.id}"}>View Ticket</.link>
      </section>

      <div :if={@show_ticket_form} class="modal-backdrop" phx-window-keydown="hide_ticket_form" phx-key="Escape">
        <section class="modal" phx-click-away="hide_ticket_form">
          <div class="section-heading">
            <h2>Create Ticket</h2>
            <button type="button" class="icon-button" phx-click="hide_ticket_form">Close</button>
          </div>
          <form phx-submit="create_ticket">
            <input name="ticket[customer_name]" placeholder="Customer name" aria-label="Customer name" required />
            <input name="ticket[customer_email]" type="email" placeholder="Customer email" aria-label="Customer email" required />
            <input name="ticket[title]" placeholder="Issue title" aria-label="Issue title" required />
            <textarea name="ticket[details]" placeholder="Optional additional details" aria-label="Additional details"></textarea>
            <button class="primary" type="submit">Create Ticket</button>
          </form>
        </section>
      </div>
    </div>
    """
  end

  defp to_source_maps(snippets) do
    Enum.map(snippets, fn item ->
      %{
        "title" => item.title,
        "slug" => item.slug,
        "path" => item.path,
        "snippet" => item.snippet
      }
    end)
  end

  defp merge_sources(existing, new) do
    (existing ++ new)
    |> Enum.uniq_by(& &1["slug"])
  end

  defp sources_from_messages(messages) do
    messages
    |> Enum.flat_map(& &1.sources)
    |> Enum.uniq_by(& &1["slug"])
  end
end
