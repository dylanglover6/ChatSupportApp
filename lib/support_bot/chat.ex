defmodule SupportBot.Chat do
  import Ecto.Query

  alias SupportBot.Chat.{Conversation, Message}
  alias SupportBot.Repo

  def create_conversation(title \\ "New support chat") do
    %Conversation{} |> Conversation.changeset(%{title: title}) |> Repo.insert!()
  end

  def get_conversation!(id), do: Repo.get!(Conversation, id) |> Repo.preload(:messages)

  def latest_conversation do
    Conversation
    |> order_by([c], desc: c.updated_at, desc: c.id)
    |> limit(1)
    |> Repo.one()
  end

  def latest_or_create_conversation(title \\ "FlowDesk support chat") do
    latest_conversation() || create_conversation(title)
  end

  def list_messages(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at, asc: m.id)
    |> Repo.all()
  end

  def add_message(conversation_id, role, content, sources \\ []) do
    %Message{}
    |> Message.changeset(%{
      conversation_id: conversation_id,
      role: role,
      content: content,
      sources: sources
    })
    |> Repo.insert!()
  end
end
