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

  def latest_or_create_conversation(title \\ "Support chat") do
    latest_conversation() || create_conversation(title)
  end

  def list_messages(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at, asc: m.id)
    |> Repo.all()
  end

  def add_message(conversation_id, role, content, sources \\ []) do
    message =
      %Message{}
      |> Message.changeset(%{
        conversation_id: conversation_id,
        role: role,
        content: content,
        sources: sources
      })
      |> Repo.insert!()

    broadcast(conversation_id, {:new_message, message})
    message
  end

  def set_agent_active(conversation_id, active?, agent_name \\ nil) do
    conversation =
      Conversation
      |> Repo.get!(conversation_id)
      |> Conversation.changeset(%{agent_active: active?, active_agent_name: agent_name})
      |> Repo.update!()

    broadcast(conversation_id, {:agent_status, active?, agent_name})
    conversation
  end

  def subscribe(conversation_id) do
    Phoenix.PubSub.subscribe(SupportBot.PubSub, topic(conversation_id))
  end

  defp broadcast(conversation_id, message) do
    Phoenix.PubSub.broadcast(SupportBot.PubSub, topic(conversation_id), message)
  end

  defp topic(conversation_id), do: "conversation:#{conversation_id}"
end
