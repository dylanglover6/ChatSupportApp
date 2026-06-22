defmodule SupportBot.Tickets.TicketReply do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticket_replies" do
    field :author_name, :string
    field :body, :string
    field :reply_type, :string
    belongs_to :ticket, SupportBot.Tickets.Ticket
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [:ticket_id, :author_name, :body, :reply_type])
    |> validate_required([:ticket_id, :author_name, :body, :reply_type])
    |> validate_inclusion(:reply_type, ["agent_reply", "internal_note"])
  end
end
