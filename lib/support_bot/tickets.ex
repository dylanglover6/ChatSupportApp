defmodule SupportBot.Tickets do
  import Ecto.Query

  alias SupportBot.AI.Client
  alias SupportBot.Chat
  alias SupportBot.Repo
  alias SupportBot.Tickets.{Assignment, Ticket, TicketEvent, TicketReply}

  def list_tickets do
    Ticket
    |> order_by([t], desc: t.inserted_at)
    |> preload(:assigned_agent)
    |> Repo.all()
  end

  def recent_events(limit \\ 8) do
    TicketEvent
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

  def create_from_conversation(conversation_id, attrs, sources) do
    messages = Chat.list_messages(conversation_id)
    summary = Client.summarize_ticket(messages, attrs, sources)
    {agent, status, reason} = Assignment.assign(summary.category)

    ticket_attrs =
      attrs
      |> Map.merge(summary)
      |> Map.merge(%{
        "conversation_id" => conversation_id,
        "status" => status,
        "assigned_agent_id" => agent.id,
        "assignment_reason" => reason,
        "kb_sources" => sources
      })

    Repo.transaction(fn ->
      case %Ticket{} |> Ticket.changeset(ticket_attrs) |> Repo.insert() do
        {:ok, ticket} ->
          add_event(ticket.id, "ticket_created", "Ticket created from chatbot conversation.")
          add_event(ticket.id, "ticket_assigned", "Ticket assigned to #{agent.name}.")
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

      type =
        if reply.reply_type == "agent_reply",
          do: "Agent reply saved.",
          else: "Internal note saved."

      add_event(ticket_id, reply.reply_type, type)

      if reply.reply_type == "agent_reply" do
        ticket = Repo.get!(Ticket, ticket_id)
        ticket |> Ticket.changeset(%{status: "Waiting on Customer"}) |> Repo.update!()
        add_event(ticket_id, "status_changed", "Status changed to Waiting on Customer.")
      end

      reply
    end)
  end

  def generate_agent_assist(ticket_id) do
    ticket = get_ticket!(ticket_id)
    assist = Client.agent_assist(ticket, ticket.conversation.messages)

    ticket
    |> Ticket.changeset(%{agent_assist: assist})
    |> Repo.update!()
  end

  defp add_event(ticket_id, type, message) do
    %TicketEvent{}
    |> TicketEvent.changeset(%{ticket_id: ticket_id, event_type: type, message: message})
    |> Repo.insert!()
  end
end
