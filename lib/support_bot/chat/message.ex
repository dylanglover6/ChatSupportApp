defmodule SupportBot.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :role, :string
    field :content, :string
    field :sources, {:array, :map}, default: []
    belongs_to :conversation, SupportBot.Chat.Conversation
    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :role, :content, :sources])
    |> validate_required([:conversation_id, :role, :content])
    |> validate_inclusion(:role, ["user", "assistant", "system", "agent"])
  end
end
