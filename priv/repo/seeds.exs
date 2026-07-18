alias SupportBot.Agents.Agent
alias SupportBot.{Chat, Tickets}
alias SupportBot.Repo
alias SupportBot.Tickets.Ticket

agents = [
  %{
    name: "Maya Chen",
    color: "Blue",
    specialties: ["Hiring", "General"],
    expertise_level: 3,
    shift_start: ~T[08:00:00],
    shift_end: ~T[16:00:00]
  },
  %{
    name: "Jordan Lee",
    color: "Green",
    specialties: ["Projects", "Docs"],
    expertise_level: 2,
    shift_start: ~T[12:00:00],
    shift_end: ~T[20:00:00]
  },
  %{
    name: "Sofia Ramirez",
    color: "Purple",
    specialties: ["Docs", "General"],
    expertise_level: 2,
    shift_start: ~T[16:00:00],
    shift_end: ~T[23:59:59]
  },
  %{
    name: "Marcus Taylor",
    color: "Orange",
    specialties: ["Projects", "General"],
    expertise_level: 1,
    shift_start: ~T[22:00:00],
    shift_end: ~T[06:00:00]
  }
]

Enum.each(agents, fn attrs ->
  case Repo.get_by(Agent, name: attrs.name) do
    nil -> %Agent{} |> Agent.changeset(attrs) |> Repo.insert!()
    agent -> agent |> Agent.changeset(attrs) |> Repo.update!()
  end
end)

if Repo.aggregate(Ticket, :count) == 0 do
  seed_ticket = fn customer_name, customer_email, title, exchange, final ->
    conversation = Chat.create_conversation(title)

    Enum.each(exchange, fn {role, content} -> Chat.add_message(conversation.id, role, content) end)

    {:ok, ticket} =
      Tickets.create_from_conversation(
        conversation.id,
        %{"customer_name" => customer_name, "customer_email" => customer_email, "title" => title},
        []
      )

    case final do
      :new ->
        ticket

      :waiting_for_agent ->
        ticket |> Ticket.changeset(%{status: "Waiting for Agent"}) |> Repo.update!()

      :open ->
        Tickets.open_ticket(ticket.id)

      :resolved ->
        Tickets.open_ticket(ticket.id)
        Tickets.resolve_ticket(ticket.id)

      :closed ->
        Tickets.open_ticket(ticket.id)
        Tickets.resolve_ticket(ticket.id)
        Tickets.close_ticket(ticket.id)

      :urgent_open ->
        escalated = Tickets.escalate_ticket(ticket.id)
        escalated |> Ticket.changeset(%{status: "Open"}) |> Repo.update!()
    end
  end

  seed_ticket.(
    "Priya Nandakumar",
    "priya.n@example.com",
    "Resume link returns a 404",
    [
      {"user", "Hi, I tried the resume download link on the homepage and it 404'd for me. Can someone check?"},
      {"assistant", "Thanks for flagging that — I don't see anything in DylanDocs about a known issue with the resume link. Want me to leave a message for Dylan so he can take a look?"}
    ],
    :waiting_for_agent
  )

  seed_ticket.(
    "Ben Okafor",
    "ben.okafor@example.com",
    "Question about the support platform's architecture",
    [
      {"user", "This support desk is pretty slick — what's actually powering the live chat takeover?"},
      {"assistant", "Great question! It's Phoenix LiveView + Phoenix PubSub — see [[project-support-platform]] for the full write-up, including the LLM integration and the takeover mechanism."},
      {"user", "Nice, I'd love to hear more about the tradeoffs from Dylan directly if he has a minute."}
    ],
    :new
  )

  seed_ticket.(
    "Alicia Brandt",
    "alicia.brandt@example.com",
    "Typo on the skills page",
    [
      {"user", "Small thing — the skills page spells it 'Pheonix' instead of 'Phoenix' in one spot."},
      {"assistant", "Thanks for catching that! I don't have a way to edit DylanDocs myself, but I'll leave a message so Dylan can fix it."}
    ],
    :resolved
  )

  seed_ticket.(
    "Marcus Whitfield",
    "marcus.whitfield@example.com",
    "Are you open to full-time roles right now?",
    [
      {"user", "Loved the site and the case study on the support platform. Are you currently open to full-time opportunities?"},
      {"assistant", "I can't speak to Dylan's current availability, but I'd love to pass this along — want to leave a message with a bit more detail?"}
    ],
    :closed
  )

  seed_ticket.(
    "Jamie Sun",
    "jamie.sun@example.com",
    "Urgent — need to reach Dylan about a live incident",
    [
      {"user", "This is urgent — we have a production incident and need to reach Dylan asap about something broken in a shared integration."},
      {"assistant", "That sounds urgent — I don't have any information about ongoing incidents in DylanDocs, so let me get this in front of Dylan's team right away. Leaving a message now."}
    ],
    :urgent_open
  )

  seed_ticket.(
    "Taylor Reyes",
    "taylor.reyes@example.com",
    "Just wanted to say the site is awesome",
    [
      {"user", "No question really, just wanted to say this site is awesome — love the retro terminal vibe."},
      {"assistant", "That means a lot, thanks! Feel free to poke around DylanDocs or ask me anything about how it's built."}
    ],
    :resolved
  )

  sample_conversation = Chat.create_conversation("Support chat")

  Enum.each(
    [
      {"user", "What are Dylan's strongest skills?"},
      {"assistant", "Dylan's strongest, most established skills are in [[skills-languages]] and [[skills-frameworks]] — he's also currently leveling up in Elixir/Phoenix by building this very platform. Want the deep-dive?"}
    ],
    fn {role, content} -> Chat.add_message(sample_conversation.id, role, content) end
  )
end
