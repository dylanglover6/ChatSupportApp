defmodule SupportBotWeb.ChatLive do
  use SupportBotWeb, :live_view

  alias SupportBot.{AI.Client, AI.DocLinks, Chat, Tickets}
  alias SupportBot.KB.Search
  alias SupportBotWeb.RateLimit

  @impl true
  def mount(_params, session, socket) do
    visitor_id = RateLimit.visitor_id(session)
    conversation = Chat.latest_or_create_conversation(visitor_id, "Support chat")
    messages = Chat.list_messages(conversation.id)

    if connected?(socket), do: Chat.subscribe(conversation.id)

    socket =
      socket
      |> assign(:page_title, "Chat")
      |> assign(:conversation, conversation)
      |> assign(:messages, messages)
      |> assign(:sources, sources_from_messages(messages))
      |> assign(:message, "")
      |> assign(:thinking, false)
      |> assign(:show_ticket_form, false)
      |> assign(:created_ticket, nil)
      |> assign(:visitor_id, visitor_id)
      |> assign(:rate_actor, RateLimit.actor(socket, session))
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

  # The background reply finished; the message itself already arrived via {:new_message}.
  def handle_info({:reply_ready, sources, _status}, socket) do
    {:noreply,
     socket
     |> assign(:sources, merge_sources(socket.assigns.sources, sources))
     |> assign(:thinking, false)}
  end

  @impl true
  def handle_event("send", %{"message" => message}, socket) do
    message = message |> String.trim() |> String.slice(0, Client.max_message_chars())

    cond do
      message == "" ->
        {:noreply, socket}

      match?({:error, :rate_limited, _}, RateLimit.check(:chat, socket.assigns.rate_actor)) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "You're sending messages a bit too fast. Give it a few seconds."
         )}

      contact_intent?(message) ->
        open_contact_form(socket, message)

      true ->
        deliver(socket, message)
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
    conversation = Chat.create_conversation("Support chat", socket.assigns.visitor_id)

    {:noreply,
     socket
     |> assign(:conversation, conversation)
     |> assign(:messages, [])
     |> assign(:sources, [])
     |> assign(:message, "")
     |> assign(:show_ticket_form, false)
     |> assign(:created_ticket, nil)}
  end

  def handle_event("create_ticket", %{"ticket" => attrs} = params, socket) do
    cond do
      # A bot populated the hidden honeypot field, silently no-op (no AI/DB work),
      # just dismiss the form so the bot can't tell it was rejected.
      honeypot_filled?(params) ->
        {:noreply, assign(socket, :show_ticket_form, false)}

      match?({:error, :rate_limited, _}, RateLimit.check(:ticket, socket.assigns.rate_actor)) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "You've submitted a lot just now. Please try again in a few minutes."
         )}

      true ->
        create_ticket(socket, attrs)
    end
  end

  # When a visitor asks to reach Dylan directly, skip the AI and open the ticket form.
  defp open_contact_form(socket, message) do
    conversation_id = socket.assigns.conversation.id
    user = Chat.add_message(conversation_id, "user", message)
    Tickets.maybe_reopen_for_conversation(conversation_id)

    reply =
      "Sure! I can pass a message straight to Dylan. Fill out the form and he'll follow up directly."

    assistant = Chat.add_message(conversation_id, "assistant", reply)

    {:noreply,
     socket
     |> assign(:messages, socket.assigns.messages ++ [user, assistant])
     |> assign(:message, "")
     |> assign(:show_ticket_form, true)}
  end

  @contact_intent ~r/leave (him )?(a )?(message|note)|message (for|to) dylan|contact (support|dylan|him)|get in touch|reach (out to )?dylan|talk to (a person|a human|dylan|him)|speak (to|with) dylan|(a |talk to a )?human( agent| support)?/i
  defp contact_intent?(message), do: Regex.match?(@contact_intent, message)

  defp honeypot_filled?(params), do: String.trim(Map.get(params, "hp_url", "")) != ""

  defp deliver(socket, message) do
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
      # The AI call can take 15-20s, so run it off the LiveView process and show a
      # "thinking" indicator meanwhile. The assistant message reaches us over PubSub
      # (Chat.add_message broadcasts); this task just signals completion + sources.
      reply_to = self()
      actor = socket.assigns.rate_actor

      Task.start(fn ->
        {sources, status} = generate_reply(conversation_id, message, actor)
        send(reply_to, {:reply_ready, sources, status})
      end)

      {:noreply,
       socket
       |> assign(:messages, socket.assigns.messages ++ [user])
       |> assign(:message, "")
       |> assign(:thinking, true)
       |> assign(:show_ticket_form, false)}
    end
  end

  defp generate_reply(conversation_id, message, actor) do
    snippets = Search.search(message)
    sources = to_source_maps(snippets)
    history = Chat.list_messages(conversation_id)
    {response, status} = Client.chat(message, history, snippets, "/chat", actor)
    Chat.add_message(conversation_id, "assistant", response, sources)
    {sources, status}
  rescue
    _ -> {[], :fallback}
  end

  defp create_ticket(socket, attrs) do
    sources = socket.assigns.sources

    case Tickets.create_from_conversation(socket.assigns.conversation.id, attrs, sources) do
      {:ok, ticket} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ticket created and assigned.")
         |> assign(:created_ticket, SupportBot.Tickets.get_ticket!(ticket.id))
         |> assign(:show_ticket_form, false)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Sorry, that ticket couldn't be created. Please check the fields and try again."
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-page">
      <section class="panel chat-panel">
        <div class="section-heading">
          <h2>
            {if @agent_active, do: "Live chat with #{@active_agent_name}", else: "Chat with DylanBot"}
          </h2>
          <div class="header-actions">
            <button type="button" phx-click="show_ticket_form">Leave a Message for Dylan</button>
            <button type="button" phx-click="new_chat">New Chat</button>
          </div>
        </div>
        <p :if={@agent_active} class="widget-escalated">
          {@active_agent_name} has joined this chat. DylanBot is paused.
        </p>
        <div id="chat-log" class="chat-log" phx-hook="AutoScroll">
          <div :if={@messages == []} class="message assistant">
            Howdy! Ask me about Dylan's skills, projects, or how this platform is built,
            or just say hi and I'll take it from there.
          </div>
          <div :for={message <- @messages} class={"message #{message.role}"}>
            <span class="message-body" phx-no-format>{if message.role == "assistant", do: DocLinks.render(message.content), else: message.content}</span>
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
          <div :if={@thinking} class="message assistant thinking" aria-label="DylanBot is thinking">
            <span class="thinking-dots" aria-hidden="true"><span></span><span></span><span></span></span>
          </div>
        </div>

        <form phx-submit="send" class="chat-form">
          <input
            name="message"
            value={@message}
            placeholder={
              if @agent_active,
                do: "Message #{@active_agent_name}...",
                else: "Ask DylanBot something..."
            }
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
        <.link class="button primary" navigate={~p"/status/#{@created_ticket.public_token}"}>
          Check ticket status →
        </.link>
      </section>

      <div
        :if={@show_ticket_form}
        class="modal-backdrop"
        phx-window-keydown="hide_ticket_form"
        phx-key="Escape"
      >
        <section class="modal" phx-click-away="hide_ticket_form">
          <div class="section-heading">
            <h2>Create Ticket</h2>
            <button type="button" class="icon-button" phx-click="hide_ticket_form">Close</button>
          </div>
          <form phx-submit="create_ticket">
            <input
              type="text"
              name="hp_url"
              class="hp-field"
              tabindex="-1"
              autocomplete="off"
              aria-hidden="true"
            />
            <input
              name="ticket[customer_name]"
              placeholder="Customer name"
              aria-label="Customer name"
              required
            />
            <input
              name="ticket[customer_email]"
              type="email"
              placeholder="Customer email"
              aria-label="Customer email"
              required
            />
            <input name="ticket[title]" placeholder="Issue title" aria-label="Issue title" required />
            <textarea
              name="ticket[details]"
              placeholder="Optional additional details"
              aria-label="Additional details"
            ></textarea>
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
