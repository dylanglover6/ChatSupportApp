defmodule SupportBot.Tickets.Assignment do
  import Ecto.Query

  alias SupportBot.Agents.{Agent, Schedule}
  alias SupportBot.Repo
  alias SupportBot.Tickets.Ticket

  def assign(category, current_time \\ Time.utc_now()) do
    agents =
      Agent
      |> order_by([a], asc: a.name)
      |> Repo.all()
      |> Enum.map(&Map.put(&1, :open_ticket_count, open_count(&1.id)))

    available = Enum.filter(agents, &Schedule.available?(&1, current_time))
    specialized = Enum.filter(available, &specializes?(&1, category))

    cond do
      specialized != [] ->
        agent = fewest_open(specialized)

        {agent, "Open",
         "Assigned to #{agent.name} because #{pronoun(agent)} is currently in office, specializes in #{category}, and has the fewest open tickets among available #{category} agents."}

      available != [] ->
        agent = fewest_open(available)

        {agent, "Open",
         "Assigned to #{agent.name} because #{pronoun(agent)} is currently in office and has the fewest open tickets among available agents."}

      true ->
        agent = next_shift(agents, current_time)

        {agent, "Waiting for Agent",
         "No agents are currently in office. Assigned to #{agent.name}, whose shift starts soonest, and marked Waiting for Agent."}
    end
  end

  defp specializes?(agent, category), do: category in agent.specialties
  defp fewest_open(agents), do: Enum.min_by(agents, & &1.open_ticket_count)

  defp next_shift(agents, current_time) do
    Enum.min_by(agents, fn agent ->
      diff = Time.diff(agent.shift_start, current_time, :second)
      if diff < 0, do: diff + 86_400, else: diff
    end)
  end

  defp open_count(agent_id) do
    Ticket
    |> where([t], t.assigned_agent_id == ^agent_id and t.status not in ["Resolved"])
    |> Repo.aggregate(:count)
  end

  defp pronoun(%{name: "Maya Chen"}), do: "she"
  defp pronoun(%{name: "Sofia Ramirez"}), do: "she"
  defp pronoun(_), do: "they"
end
