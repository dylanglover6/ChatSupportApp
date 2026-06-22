defmodule SupportBot.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :title, :string
    has_many :messages, SupportBot.Chat.Message
    has_many :tickets, SupportBot.Tickets.Ticket
    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
