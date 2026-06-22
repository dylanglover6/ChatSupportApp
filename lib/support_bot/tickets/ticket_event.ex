defmodule SupportBot.Tickets.TicketEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticket_events" do
    field :event_type, :string
    field :message, :string
    belongs_to :ticket, SupportBot.Tickets.Ticket
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:ticket_id, :event_type, :message])
    |> validate_required([:ticket_id, :event_type, :message])
  end
end
