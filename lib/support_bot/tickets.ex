defmodule SupportBot.Tickets do
  import Ecto.Query

  alias SupportBot.AI.Client
  alias SupportBot.Agents.Agent
  alias SupportBot.Chat
  alias SupportBot.Repo
  alias SupportBot.Tickets.{Assignment, Ticket, TicketEvent, TicketReply}

  @doc """
  Tickets visible to `visitor_id`: the seed/mock tickets (no visitor_id) plus the
  ones this visitor created. Keeps one visitor from seeing another's tickets — and
  their customer emails — on the public DylanSupport desk.
  """
  def list_tickets(visitor_id) do
    Ticket
    |> visible_to(visitor_id)
    |> order_by([t], desc: t.urgent, desc: t.inserted_at)
    |> preload(:assigned_agent)
    |> Repo.all()
  end

  def recent_events(visitor_id, limit \\ 8) do
    TicketEvent
    |> join(:inner, [e], t in assoc(e, :ticket))
    |> where([_e, t], is_nil(t.visitor_id) or t.visitor_id == ^visitor_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> preload(:ticket)
    |> Repo.all()
  end

  def get_ticket!(id) do
    Ticket
    |> Repo.get!(id)
    |> Repo.preload([:assigned_agent, :events, :replies, conversation: :messages])
  end

  @doc """
  Looks up a ticket by its public capability token for the visitor-facing status
  page. Read-only, returns nil if the token doesn't match. Preloads the pieces the
  status page shows (agent, events, replies) — but never internal notes are exposed
  by the page itself.
  """
  def get_ticket_by_token(token) when is_binary(token) and token != "" do
    case Repo.get_by(Ticket, public_token: token) do
      nil -> nil
      ticket -> Repo.preload(ticket, [:assigned_agent, :events, :replies])
    end
  end

  def get_ticket_by_token(_), do: nil

  defp gen_public_token,
    do: 12 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  @doc "Loads a ticket only if it's visible to `visitor_id` (own or mock); else nil."
  def get_visible_ticket(id, visitor_id) do
    Ticket
    |> visible_to(visitor_id)
    |> Repo.get(id)
    |> case do
      nil ->
        nil

      ticket ->
        Repo.preload(ticket, [:assigned_agent, :events, :replies, conversation: :messages])
    end
  end

  defp visible_to(query, visitor_id) do
    from t in query, where: is_nil(t.visitor_id) or t.visitor_id == ^visitor_id
  end

  def create_from_conversation(conversation_id, attrs, sources) do
    messages = Chat.list_messages(conversation_id)
    conversation = Chat.get_conversation!(conversation_id)
    summary = Client.summarize_ticket(messages, attrs, sources)

    {agent, status, off_shift?, reason} =
      Assignment.assign(summary.category, summary.support_level, summary.urgent)

    ticket_attrs =
      attrs
      |> Map.merge(Map.new(summary, fn {key, value} -> {Atom.to_string(key), value} end))
      |> Map.merge(%{
        "conversation_id" => conversation_id,
        "status" => status,
        "assigned_agent_id" => agent.id,
        "assignment_reason" => reason,
        "kb_sources" => sources,
        "visitor_id" => conversation.visitor_id,
        "public_token" => gen_public_token()
      })

    Repo.transaction(fn ->
      case %Ticket{} |> Ticket.changeset(ticket_attrs) |> Repo.insert() do
        {:ok, ticket} ->
          add_event(ticket.id, "ticket_created", "Ticket created from chatbot conversation.")
          add_event(ticket.id, "ticket_assigned", "Ticket assigned to #{agent.name}.")

          if off_shift? do
            add_event(
              ticket.id,
              "off_shift_assignment",
              "#{agent.name} was assigned off-shift because this ticket is urgent and no level 3 agent is currently in office."
            )
          end

          ticket

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def add_reply(ticket_id, attrs) do
    Repo.transaction(fn ->
      reply =
        %TicketReply{}
        |> TicketReply.changeset(Map.put(attrs, "ticket_id", ticket_id))
        |> Repo.insert!()

      ticket = Repo.get!(Ticket, ticket_id)

      case reply.kind do
        "note" ->
          add_event(ticket_id, "note_added", "Internal note saved.")

        "email" ->
          add_event(
            ticket_id,
            "email_sent",
            "Simulated email sent to #{reply.email_to}. SIMULATED, not delivered."
          )

          do_resolve(ticket)

        "chat" ->
          Chat.add_message(ticket.conversation_id, "agent", reply.body)
          add_event(ticket_id, "chat_message", "#{reply.author_name} sent a live chat message.")
          do_resolve(ticket)
      end

      reply
    end)
  end

  def open_ticket(ticket_id) do
    ticket = Repo.get!(Ticket, ticket_id)

    if ticket.status == "New" do
      ticket |> Ticket.changeset(%{status: "Open"}) |> Repo.update!()
      add_event(ticket_id, "status_changed", "Status changed to Open.")
    end

    get_ticket!(ticket_id)
  end

  def resolve_ticket(ticket_id) do
    Repo.get!(Ticket, ticket_id) |> do_resolve()
    get_ticket!(ticket_id)
  end

  def close_ticket(ticket_id) do
    ticket = Repo.get!(Ticket, ticket_id)
    ticket |> Ticket.changeset(%{status: "Closed"}) |> Repo.update!()
    add_event(ticket_id, "status_changed", "Status changed to Closed.")
    get_ticket!(ticket_id)
  end

  def reopen_ticket(ticket_id) do
    ticket = Repo.get!(Ticket, ticket_id)
    ticket |> Ticket.changeset(%{status: "Open"}) |> Repo.update!()
    add_event(ticket_id, "reopened", "Ticket reopened.")
    get_ticket!(ticket_id)
  end

  def escalate_ticket(ticket_id) do
    ticket = Repo.get!(Ticket, ticket_id)
    {agent, status, off_shift?, reason} = Assignment.assign(ticket.category, 3, true)

    ticket
    |> Ticket.changeset(%{
      urgent: true,
      support_level: 3,
      assigned_agent_id: agent.id,
      assignment_reason: reason,
      status: if(ticket.status == "New", do: status, else: ticket.status)
    })
    |> Repo.update!()

    add_event(ticket_id, "escalated", "Ticket escalated and reassigned to #{agent.name}.")

    if off_shift? do
      add_event(
        ticket_id,
        "off_shift_assignment",
        "#{agent.name} was assigned off-shift because this ticket is urgent and no level 3 agent is currently in office."
      )
    end

    get_ticket!(ticket_id)
  end

  def reassign_ticket(ticket_id, agent_id) do
    agent = Repo.get!(Agent, agent_id)

    Repo.get!(Ticket, ticket_id)
    |> Ticket.changeset(%{
      assigned_agent_id: agent.id,
      assignment_reason: "Manually reassigned to #{agent.name}."
    })
    |> Repo.update!()

    add_event(ticket_id, "reassigned", "Ticket manually reassigned to #{agent.name}.")
    get_ticket!(ticket_id)
  end

  def take_over_chat(ticket_id) do
    ticket = get_ticket!(ticket_id)

    agent_name =
      if ticket.assigned_agent, do: ticket.assigned_agent.name, else: "A DylanSupport agent"

    Chat.set_agent_active(ticket.conversation_id, true, agent_name)

    Chat.add_message(
      ticket.conversation_id,
      "system",
      "#{agent_name} from DylanSupport joined the chat."
    )

    add_event(ticket_id, "agent_takeover", "#{agent_name} took over the live chat.")

    get_ticket!(ticket_id)
  end

  def hand_back_chat(ticket_id) do
    ticket = get_ticket!(ticket_id)
    agent_name = ticket.conversation.active_agent_name || "The agent"

    Chat.set_agent_active(ticket.conversation_id, false, nil)

    Chat.add_message(
      ticket.conversation_id,
      "system",
      "#{agent_name} left the chat. DylanBot is back."
    )

    add_event(ticket_id, "agent_handback", "#{agent_name} handed the chat back to DylanBot.")

    get_ticket!(ticket_id)
  end

  def maybe_reopen_for_conversation(conversation_id) do
    Ticket
    |> where([t], t.conversation_id == ^conversation_id and t.status in ["Resolved", "Closed"])
    |> Repo.all()
    |> Enum.each(fn ticket ->
      ticket |> Ticket.changeset(%{status: "Open"}) |> Repo.update!()
      add_event(ticket.id, "reopened", "Ticket reopened after a new customer message.")
    end)
  end

  def generate_agent_assist(ticket_id) do
    ticket = get_ticket!(ticket_id)
    assist = Client.agent_assist(ticket, ticket.conversation.messages)

    ticket
    |> Ticket.changeset(%{agent_assist: assist})
    |> Repo.update!()
  end

  defp do_resolve(ticket) do
    if ticket.status != "Resolved" do
      ticket |> Ticket.changeset(%{status: "Resolved"}) |> Repo.update!()
      add_event(ticket.id, "status_changed", "Status changed to Resolved.")
    end
  end

  defp add_event(ticket_id, type, message) do
    %TicketEvent{}
    |> TicketEvent.changeset(%{ticket_id: ticket_id, event_type: type, message: message})
    |> Repo.insert!()
  end
end
