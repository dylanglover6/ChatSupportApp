defmodule SupportBot.Agents do
  import Ecto.Query

  alias SupportBot.Agents.{Agent, Schedule}
  alias SupportBot.Repo
  alias SupportBot.Tickets.Ticket

  def list_agents do
    Agent
    |> order_by([a], asc: a.name)
    |> Repo.all()
    |> Enum.map(&with_open_count/1)
  end

  def get_agent!(id), do: Repo.get!(Agent, id)

  def open_count(agent_id) do
    Ticket
    |> where([t], t.assigned_agent_id == ^agent_id and t.status not in ["Resolved"])
    |> Repo.aggregate(:count)
  end

  defp with_open_count(agent) do
    Map.put(agent, :open_ticket_count, open_count(agent.id))
    |> Map.put(
      :availability,
      if(Schedule.available?(agent), do: "In Office", else: "Out of Office")
    )
  end
end
