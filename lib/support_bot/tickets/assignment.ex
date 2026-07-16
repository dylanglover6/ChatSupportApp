defmodule SupportBot.Tickets.Assignment do
  import Ecto.Query

  alias SupportBot.Agents.{Agent, Schedule}
  alias SupportBot.Repo
  alias SupportBot.Tickets.Ticket

  @doc """
  Returns `{agent, status, reason, off_shift?}`. Urgent tickets always route to an
  expertise-level-3 agent, on shift if possible; otherwise the least-loaded L3 agent
  is assigned off-shift and the ticket is marked "Waiting for Agent". Non-urgent
  tickets prefer an on-shift, category-specialized agent whose expertise level covers
  the ticket's support level, falling back to any qualified on-shift agent, then any
  on-shift agent, then whoever's shift starts soonest.
  """
  def assign(category, support_level \\ 1, urgent \\ false, current_time \\ Time.utc_now()) do
    agents =
      Agent
      |> order_by([a], asc: a.name)
      |> Repo.all()
      |> Enum.map(&Map.put(&1, :open_ticket_count, open_count(&1.id)))

    available = Enum.filter(agents, &Schedule.available?(&1, current_time))

    if urgent do
      assign_urgent(agents, available)
    else
      assign_standard(agents, available, category, support_level, current_time)
    end
  end

  defp assign_urgent(agents, available) do
    l3_available = Enum.filter(available, &(&1.expertise_level >= 3))

    if l3_available != [] do
      agent = fewest_open(l3_available)

      {agent, "New", false,
       "Assigned to #{agent.name} because #{subject(agent)} #{agree(agent, "is")} a level 3 agent currently in office and this ticket was flagged urgent."}
    else
      l3_agents = Enum.filter(agents, &(&1.expertise_level >= 3))
      agent = fewest_open(l3_agents)

      {agent, "Waiting for Agent", true,
       "No level 3 agents are currently in office. Assigned off-shift to #{agent.name} (least-loaded L3 agent) because this ticket was flagged urgent."}
    end
  end

  defp assign_standard(agents, available, category, support_level, current_time) do
    qualified = Enum.filter(available, &(&1.expertise_level >= support_level))
    specialized = Enum.filter(qualified, &specializes?(&1, category))

    cond do
      specialized != [] ->
        agent = fewest_open(specialized)

        {agent, "New", false,
         "Assigned to #{agent.name} because #{subject(agent)} #{agree(agent, "is")} currently in office, #{agree(agent, "specializes")} in #{category}, #{agree(agent, "meets")} the required expertise level, and #{agree(agent, "has")} the fewest open tickets among available #{category} agents."}

      qualified != [] ->
        agent = fewest_open(qualified)

        {agent, "New", false,
         "Assigned to #{agent.name} because #{subject(agent)} #{agree(agent, "is")} currently in office, #{agree(agent, "meets")} the required expertise level, and #{agree(agent, "has")} the fewest open tickets among available agents."}

      available != [] ->
        agent = fewest_open(available)

        {agent, "New", false,
         "Assigned to #{agent.name} because #{subject(agent)} #{agree(agent, "is")} currently in office and #{agree(agent, "has")} the fewest open tickets among available agents."}

      true ->
        eligible = Enum.filter(agents, &(&1.expertise_level >= support_level))
        pool = if eligible != [], do: eligible, else: agents
        agent = next_shift(pool, current_time)

        {agent, "Waiting for Agent", false,
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
    |> where([t], t.assigned_agent_id == ^agent_id and t.status not in ["Resolved", "Closed"])
    |> Repo.aggregate(:count)
  end

  defp subject(%{name: "Maya Chen"}), do: "she"
  defp subject(%{name: "Sofia Ramirez"}), do: "she"
  defp subject(_), do: "they"

  @singular %{"is" => "is", "has" => "has", "meets" => "meets", "specializes" => "specializes"}
  @plural %{"is" => "are", "has" => "have", "meets" => "meet", "specializes" => "specialize"}

  defp agree(%{name: name}, verb) when name in ["Maya Chen", "Sofia Ramirez"], do: @singular[verb]
  defp agree(_agent, verb), do: @plural[verb]
end
