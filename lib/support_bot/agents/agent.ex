defmodule SupportBot.Agents.Agent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agents" do
    field :name, :string
    field :color, :string
    field :specialties, {:array, :string}, default: []
    field :shift_start, :time
    field :shift_end, :time
    field :expertise_level, :integer, default: 1
    has_many :tickets, SupportBot.Tickets.Ticket, foreign_key: :assigned_agent_id
    timestamps(type: :utc_datetime)
  end

  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [:name, :color, :specialties, :shift_start, :shift_end, :expertise_level])
    |> validate_required([:name, :color, :specialties, :shift_start, :shift_end, :expertise_level])
    |> validate_inclusion(:expertise_level, 1..3)
  end
end
