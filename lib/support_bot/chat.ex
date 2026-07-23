defmodule SupportBot.Chat do
  import Ecto.Query

  alias SupportBot.Chat.{Conversation, Message}
  alias SupportBot.Repo

  def create_conversation(title \\ "New support chat", visitor_id \\ nil) do
    %Conversation{}
    |> Conversation.changeset(%{title: title, visitor_id: visitor_id})
    |> Repo.insert!()
  end

  def get_conversation!(id), do: Repo.get!(Conversation, id) |> Repo.preload(:messages)

  @doc """
  The most recent conversation belonging to `visitor_id`. Scoping by visitor keeps
  each browser session's chat isolated — without it, every visitor would share (and
  see) the single global latest conversation.
  """
  def latest_conversation(visitor_id) when is_binary(visitor_id) do
    Conversation
    |> where([c], c.visitor_id == ^visitor_id)
    |> order_by([c], desc: c.updated_at, desc: c.id)
    |> limit(1)
    |> Repo.one()
  end

  def latest_or_create_conversation(visitor_id, title \\ "Support chat")
      when is_binary(visitor_id) do
    latest_conversation(visitor_id) || create_conversation(title, visitor_id)
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

  def unsubscribe(conversation_id) do
    Phoenix.PubSub.unsubscribe(SupportBot.PubSub, topic(conversation_id))
  end

  defp broadcast(conversation_id, message) do
    Phoenix.PubSub.broadcast(SupportBot.PubSub, topic(conversation_id), message)
  end

  defp topic(conversation_id), do: "conversation:#{conversation_id}"
end
