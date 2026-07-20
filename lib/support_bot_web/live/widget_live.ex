defmodule SupportBotWeb.WidgetLive do
  use SupportBotWeb, :live_widget

  alias SupportBot.{AI.Client, AI.DocLinks, AI.PageContext, Chat, Tickets}
  alias SupportBot.KB.Search
  alias SupportBotWeb.RateLimit

  @impl true
  def mount(_params, session, socket) do
    path = Map.get(session, "path", "/")
    visitor_id = RateLimit.visitor_id(session)
    conversation = Chat.latest_or_create_conversation(visitor_id)
    messages = Chat.list_messages(conversation.id)

    if connected?(socket), do: Chat.subscribe(conversation.id)

    {:ok,
     socket
     |> assign(:conversation, conversation)
     |> assign(:messages, messages)
     |> assign(:sources, sources_from_messages(messages))
     |> assign(:current_path, path)
     |> assign(:page_context, PageContext.for_path(path))
     |> assign(:llm_status, if(Client.llm_reachable?(), do: :ok, else: :fallback))
     |> assign(:open, false)
     |> assign(:unread_count, if(messages == [], do: 1, else: 0))
     |> assign(:message, "")
     |> assign(:thinking, false)
     |> assign(:notice, nil)
     |> assign(:show_escalation_form, false)
     |> assign(:escalated_ticket, nil)
     |> assign(:rate_actor, RateLimit.actor(socket, session))
     |> assign(:agent_active, conversation.agent_active)
     |> assign(:active_agent_name, conversation.active_agent_name)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.conversation_id == socket.assigns.conversation.id and
         message.id not in Enum.map(socket.assigns.messages, & &1.id) do
      unread =
        if socket.assigns.open,
          do: socket.assigns.unread_count,
          else: socket.assigns.unread_count + 1

      {:noreply,
       socket
       |> assign(:messages, socket.assigns.messages ++ [message])
       |> assign(:unread_count, unread)}
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

  # Background reply finished; the message itself already arrived via {:new_message}.
  def handle_info({:reply_ready, sources, status}, socket) do
    {:noreply,
     socket
     |> assign(:sources, merge_sources(socket.assigns.sources, sources))
     |> assign(:llm_status, if(status == :live, do: :ok, else: :fallback))
     |> assign(:thinking, false)}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    open = !socket.assigns.open

    socket =
      if open,
        do: socket |> assign(:unread_count, 0) |> push_event("dylanbot_opened", %{}),
        else: socket

    {:noreply, assign(socket, :open, open)}
  end

  # Opened from outside the widget (e.g. the hero "Chat" link) without leaving the page.
  def handle_event("open", _params, socket) do
    {:noreply,
     socket
     |> assign(:open, true)
     |> assign(:unread_count, 0)
     |> push_event("dylanbot_opened", %{})}
  end

  # A returning visitor has already seen the first-visit greeting; clear the waiting badge.
  def handle_event("dismiss_greeting", _params, socket) do
    if socket.assigns.messages == [] and not socket.assigns.open do
      {:noreply, assign(socket, :unread_count, 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_on_escape", _params, socket) do
    if socket.assigns.show_escalation_form do
      {:noreply, assign(socket, :show_escalation_form, false)}
    else
      {:noreply, assign(socket, :open, false)}
    end
  end

  def handle_event("path_changed", %{"path" => path}, socket) do
    {:noreply,
     socket
     |> assign(:current_path, path)
     |> assign(:page_context, PageContext.for_path(path))}
  end

  def handle_event("send", %{"message" => message}, socket) do
    {:noreply, do_send(socket, message)}
  end

  def handle_event("suggestion", %{"text" => text}, socket) do
    {:noreply, do_send(socket, text)}
  end

  def handle_event("show_escalation_form", _params, socket) do
    {:noreply, assign(socket, :show_escalation_form, true)}
  end

  def handle_event("hide_escalation_form", _params, socket) do
    {:noreply, assign(socket, :show_escalation_form, false)}
  end

  def handle_event("create_ticket", %{"ticket" => attrs} = params, socket) do
    cond do
      # A bot populated the hidden honeypot field — silently no-op and dismiss the
      # form so it can't tell the submission was dropped.
      honeypot_filled?(params) ->
        {:noreply, assign(socket, :show_escalation_form, false)}

      match?({:error, :rate_limited, _}, RateLimit.check(:ticket, socket.assigns.rate_actor)) ->
        {:noreply,
         add_notice(
           socket,
           "You've created a lot of messages just now — please try again in a few minutes."
         )}

      true ->
        case Tickets.create_from_conversation(
               socket.assigns.conversation.id,
               attrs,
               socket.assigns.sources
             ) do
          {:ok, ticket} ->
            {:noreply,
             socket
             |> assign(:escalated_ticket, Tickets.get_ticket!(ticket.id))
             |> assign(:show_escalation_form, false)}

          {:error, _changeset} ->
            {:noreply, socket}
        end
    end
  end

  defp do_send(socket, message) do
    message = message |> String.trim() |> String.slice(0, Client.max_message_chars())

    cond do
      message == "" ->
        socket

      match?({:error, :rate_limited, _}, RateLimit.check(:chat, socket.assigns.rate_actor)) ->
        add_notice(
          socket,
          "Whoa there — you're sending messages a bit too fast. Give me a few seconds!"
        )

      contact_intent?(message) ->
        open_contact_form(socket, message)

      true ->
        deliver(socket, message)
    end
  end

  # When a visitor asks to reach Dylan directly, skip the AI and open the contact form.
  defp open_contact_form(socket, message) do
    conversation_id = socket.assigns.conversation.id
    user = Chat.add_message(conversation_id, "user", message)
    Tickets.maybe_reopen_for_conversation(conversation_id)

    reply =
      "Sure — I can pass a message straight to Dylan. Fill this out and he'll follow up directly."

    assistant = Chat.add_message(conversation_id, "assistant", reply)

    socket
    |> assign(:messages, socket.assigns.messages ++ [user, assistant])
    |> assign(:message, "")
    |> assign(:notice, nil)
    |> assign(:show_escalation_form, true)
  end

  defp deliver(socket, message) do
    conversation_id = socket.assigns.conversation.id
    user = Chat.add_message(conversation_id, "user", message)
    Tickets.maybe_reopen_for_conversation(conversation_id)

    if socket.assigns.agent_active do
      socket
      |> assign(:messages, socket.assigns.messages ++ [user])
      |> assign(:message, "")
      |> assign(:notice, nil)
    else
      # The AI call can take 15-20s; run it off the LiveView process and show a
      # "thinking" indicator meanwhile. The assistant message arrives over PubSub
      # (Chat.add_message broadcasts, handled by {:new_message}); this task just
      # signals completion so we can stop the spinner and record sources/status.
      reply_to = self()
      path = socket.assigns.current_path
      actor = socket.assigns.rate_actor

      Task.start(fn ->
        {sources, status} = generate_reply(conversation_id, message, path, actor)
        send(reply_to, {:reply_ready, sources, status})
      end)

      socket
      |> assign(:messages, socket.assigns.messages ++ [user])
      |> assign(:message, "")
      |> assign(:thinking, true)
      |> assign(:notice, nil)
    end
  end

  defp generate_reply(conversation_id, message, path, actor) do
    snippets = Search.search(message)
    sources = to_source_maps(snippets)
    history = Chat.list_messages(conversation_id)
    {response, status} = Client.chat(message, history, snippets, path, actor)
    Chat.add_message(conversation_id, "assistant", response, sources)
    {sources, status}
  rescue
    _ -> {[], :fallback}
  end

  defp add_notice(socket, text), do: assign(socket, :notice, text)

  @contact_intent ~r/leave (him )?(a )?(message|note)|message (for|to) dylan|contact (support|dylan|him)|get in touch|reach (out to )?dylan|talk to (a person|a human|dylan|him)|speak (to|with) dylan|(a |talk to a )?human( agent| support)?/i
  defp contact_intent?(message), do: Regex.match?(@contact_intent, message)

  defp honeypot_filled?(params), do: String.trim(Map.get(params, "hp_url", "")) != ""

  @impl true
  def render(assigns) do
    ~H"""
    <div id="dylanbot-widget" class={["widget", @open && "is-open"]} phx-hook="WidgetPath">
      <div class="widget-bar">
        <button
          type="button"
          class="widget-bar-main"
          phx-click="toggle"
          aria-expanded={to_string(@open)}
          aria-label={if @open, do: "Close DylanBot chat", else: "Open DylanBot chat"}
        >
          <span class="widget-bar-title">
            {if @agent_active, do: String.upcase(@active_agent_name || "AGENT"), else: "DYLANBOT"}
          </span>
          <span
            class={"widget-status-dot #{cond do
              @agent_active -> "is-live"
              @llm_status == :ok -> "is-ok"
              true -> "is-fallback"
            end}"}
            title={
              cond do
                @agent_active -> "#{@active_agent_name} is live"
                @llm_status == :ok -> "Live AI model"
                true -> "Fallback mode"
              end
            }
          ></span>
          <span :if={@unread_count > 0 and not @open} class="widget-unread-badge">
            {if @unread_count > 9, do: "9+", else: @unread_count}
          </span>
        </button>
        <.link
          :if={@open}
          navigate={~p"/chat"}
          class="widget-bar-icon"
          title="Open full chat"
          aria-label="Open full chat"
        >
          <svg
            viewBox="0 0 16 16"
            width="13"
            height="13"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            aria-hidden="true"
          >
            <path d="M2 6V2h4M14 6V2h-4M2 10v4h4M14 10v4h-4" />
          </svg>
        </.link>
        <button
          type="button"
          class="widget-bar-toggle"
          phx-click="toggle"
          aria-label={if @open, do: "Close DylanBot chat", else: "Open DylanBot chat"}
        >{if @open, do: "▼", else: "▲"}</button>
      </div>

      <section
        :if={@open}
        class="widget-panel"
        phx-remove={
          JS.transition({"widget-leaving", "widget-panel-in", "widget-panel-out"}, time: 180)
        }
        phx-window-keydown="close_on_escape"
        phx-key="Escape"
      >
        <p :if={@agent_active} class="widget-escalated">
          {@active_agent_name} has joined this chat — DylanBot is paused.
        </p>

        <div id="widget-chat-log" class="widget-messages" phx-hook="AutoScroll">
          <div :if={@messages == []} class="widget-message assistant">
            <span class="widget-message-body" phx-no-format>Howdy! Ask me about Dylan's skills, projects, or this platform — or tap a suggestion below.</span>
          </div>
          <div :for={message <- @messages} class={"widget-message #{message.role}"}>
            <span class="widget-message-body" phx-no-format>{if message.role == "assistant", do: DocLinks.render(message.content), else: message.content}</span>
            <div :if={message.sources != []} class="sources">
              <.link
                :for={source <- message.sources}
                class="source-link"
                navigate={~p"/docs/#{source["slug"]}"}
              >
                {source["title"]}
              </.link>
            </div>
          </div>
          <div
            :if={@thinking}
            class="widget-message assistant thinking"
            aria-label="DylanBot is thinking"
          >
            <span class="thinking-dots" aria-hidden="true"><span></span><span></span><span></span></span>
          </div>
        </div>

        <div :if={@messages == [] and @show_escalation_form == false} class="widget-suggestions">
          <button
            :for={action <- @page_context.actions}
            type="button"
            class="widget-chip"
            phx-click="suggestion"
            phx-value-text={action}
          >
            {action}
          </button>
        </div>

        <div :if={@notice} class="widget-notice" role="status">{@notice}</div>

        <div :if={@escalated_ticket} class="widget-escalated">
          Message sent to Dylan —
          <.link navigate={~p"/status/#{@escalated_ticket.public_token}"}>check its status →</.link>
        </div>

        <div :if={@show_escalation_form} class="widget-escalation-form">
          <p class="widget-escalation-note">
            Heads up: this support desk is a portfolio demo — the ticket it creates is
            simulated and won't actually email Dylan. To really reach him, email
            <a href="mailto:dylanglover6@gmail.com">dylanglover6@gmail.com</a>
            or message him on <a
              href="https://www.linkedin.com/in/dylanglover6"
              target="_blank"
              rel="noopener noreferrer"
            >LinkedIn</a>.
          </p>
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
              placeholder="Your name"
              aria-label="Your name"
              required
            />
            <input
              name="ticket[customer_email]"
              type="email"
              placeholder="Your email"
              aria-label="Your email"
              required
            />
            <input
              name="ticket[title]"
              placeholder="What's this about?"
              aria-label="What's this about?"
              required
            />
            <div class="widget-escalation-actions">
              <button type="button" class="icon-button" phx-click="hide_escalation_form">Cancel</button>
              <button class="primary" type="submit">Leave Message</button>
            </div>
          </form>
        </div>

        <form :if={not @show_escalation_form} phx-submit="send" class="widget-input-row">
          <input
            name="message"
            value={@message}
            placeholder={
              if @agent_active, do: "Message #{@active_agent_name}...", else: "Ask DylanBot..."
            }
            aria-label="Message"
            autocomplete="off"
          />
          <button type="submit">Send</button>
        </form>

        <footer class="widget-footer">
          <div class="widget-footer-group">
            <.link navigate={~p"/docs"}>DOCS</.link>
          </div>
          <button type="button" class="widget-footer-link" phx-click="show_escalation_form">
            Contact Support
          </button>
        </footer>
      </section>
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
