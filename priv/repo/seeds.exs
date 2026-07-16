alias SupportBot.Agents.Agent
alias SupportBot.Repo

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
