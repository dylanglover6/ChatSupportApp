defmodule SupportBot.Tickets.TicketReply do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ticket_replies" do
    field :author_name, :string
    field :body, :string
    field :kind, :string
    field :email_to, :string
    field :email_subject, :string
    belongs_to :ticket, SupportBot.Tickets.Ticket
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [:ticket_id, :author_name, :body, :kind, :email_to, :email_subject])
    |> validate_required([:ticket_id, :author_name, :body, :kind])
    |> validate_inclusion(:kind, ["note", "email", "chat"])
  end
end
