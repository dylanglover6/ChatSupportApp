defmodule SupportBotWeb.WidgetLive do
  use SupportBotWeb, :live_widget

  alias SupportBot.{AI.Client, AI.DocLinks, AI.PageContext, Chat, Tickets}
  alias SupportBot.KB.Search

  @impl true
  def mount(_params, session, socket) do
    path = Map.get(session, "path", "/")
    conversation = Chat.latest_or_create_conversation()
    messages = Chat.list_messages(conversation.id)

    {:ok,
     socket
     |> assign(:conversation, conversation)
     |> assign(:messages, messages)
     |> assign(:sources, sources_from_messages(messages))
     |> assign(:current_path, path)
     |> assign(:page_context, PageContext.for_path(path))
     |> assign(:ollama_status, if(Client.ollama_reachable?(), do: :ok, else: :fallback))
     |> assign(:open, false)
     |> assign(:unread_count, 0)
     |> assign(:message, "")
     |> assign(:show_escalation_form, false)
     |> assign(:escalated_ticket, nil)}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    open = !socket.assigns.open
    socket = if open, do: assign(socket, :unread_count, 0), else: socket
    {:noreply, assign(socket, :open, open)}
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

  def handle_event("create_ticket", %{"ticket" => attrs}, socket) do
    case Tickets.create_from_conversation(socket.assigns.conversation.id, attrs, socket.assigns.sources) do
      {:ok, ticket} ->
        {:noreply,
         socket
         |> assign(:escalated_ticket, Tickets.get_ticket!(ticket.id))
         |> assign(:show_escalation_form, false)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  defp do_send(socket, message) do
    message = String.trim(message)

    if message == "" do
      socket
    else
      conversation_id = socket.assigns.conversation.id
      snippets = Search.search(message)
      sources = to_source_maps(snippets)
      history = Chat.list_messages(conversation_id)
      user = Chat.add_message(conversation_id, "user", message)
      {response, status} = Client.chat(message, history, snippets, socket.assigns.current_path)
      assistant = Chat.add_message(conversation_id, "assistant", response, sources)

      unread = if socket.assigns.open, do: 0, else: socket.assigns.unread_count + 1

      socket
      |> assign(:messages, socket.assigns.messages ++ [user, assistant])
      |> assign(:sources, merge_sources(socket.assigns.sources, sources))
      |> assign(:message, "")
      |> assign(:ollama_status, if(status == :ollama, do: :ok, else: :fallback))
      |> assign(:unread_count, unread)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="dylanbot-widget" phx-hook="WidgetPath">
      <button
        type="button"
        class="widget-fab"
        phx-click="toggle"
        aria-label={if @open, do: "Close DylanBot chat", else: "Open DylanBot chat"}
      >
        💬
        <span :if={@unread_count > 0 and not @open} class="widget-unread-badge">
          {if @unread_count > 9, do: "9+", else: @unread_count}
        </span>
      </button>

      <section :if={@open} class="widget-panel">
        <header class="widget-header">
          <span class="widget-title">DYLANBOT</span>
          <span
            class={"widget-status-dot #{if @ollama_status == :ok, do: "is-ok", else: "is-fallback"}"}
            title={if @ollama_status == :ok, do: "Ollama reachable", else: "Fallback mode"}
          >
          </span>
        </header>

        <div id="widget-chat-log" class="widget-messages" phx-hook="AutoScroll">
          <div :if={@messages == []} class="widget-message assistant">
            Howdy! Ask me about Dylan's skills, projects, or this platform — or tap a suggestion below.
          </div>
          <div :for={message <- @messages} class={"widget-message #{message.role}"}>
            {if message.role == "assistant", do: DocLinks.render(message.content), else: message.content}
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

        <div :if={@escalated_ticket} class="widget-escalated">
          Ticket created —
          <.link navigate={~p"/support/#{@escalated_ticket.id}"}>view it in DylanSupport →</.link>
        </div>

        <div :if={@show_escalation_form} class="widget-escalation-form">
          <form phx-submit="create_ticket">
            <input name="ticket[customer_name]" placeholder="Your name" required />
            <input name="ticket[customer_email]" type="email" placeholder="Your email" required />
            <input name="ticket[title]" placeholder="What's this about?" required />
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
            placeholder="Ask DylanBot..."
            autocomplete="off"
          />
          <button type="submit">Send</button>
        </form>

        <footer class="widget-footer">
          <.link navigate={~p"/chat"}>Open full chat</.link>
          <span>·</span>
          <.link navigate={~p"/docs"}>Browse DylanDocs</.link>
          <span>·</span>
          <button type="button" class="widget-footer-link" phx-click="show_escalation_form">
            Leave a message for Dylan
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
