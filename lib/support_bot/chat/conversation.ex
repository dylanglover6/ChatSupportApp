defmodule SupportBot.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :title, :string
    field :agent_active, :boolean, default: false
    field :active_agent_name, :string
    has_many :messages, SupportBot.Chat.Message
    has_many :tickets, SupportBot.Tickets.Ticket
    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :agent_active, :active_agent_name])
    |> validate_required([:title])
  end
end
