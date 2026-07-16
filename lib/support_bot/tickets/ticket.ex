defmodule SupportBot.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickets" do
    field :customer_name, :string
    field :customer_email, :string
    field :title, :string
    field :issue_summary, :string
    field :conversation_summary, :string
    field :steps_tried, :string
    field :likely_cause, :string
    field :missing_information, :string
    field :priority, :string
    field :category, :string
    field :status, :string, default: "New"
    field :support_level, :integer, default: 1
    field :urgent, :boolean, default: false
    field :assignment_reason, :string
    field :kb_sources, {:array, :map}, default: []
    field :agent_assist, :string
    field :visitor_id, :string
    field :public_token, :string
    belongs_to :conversation, SupportBot.Chat.Conversation
    belongs_to :assigned_agent, SupportBot.Agents.Agent
    has_many :events, SupportBot.Tickets.TicketEvent
    has_many :replies, SupportBot.Tickets.TicketReply
    timestamps(type: :utc_datetime)
  end

  @statuses ["New", "Open", "Waiting for Agent", "Resolved", "Closed"]

  def statuses, do: @statuses

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :conversation_id,
      :customer_name,
      :customer_email,
      :title,
      :issue_summary,
      :conversation_summary,
      :steps_tried,
      :likely_cause,
      :missing_information,
      :priority,
      :category,
      :status,
      :support_level,
      :urgent,
      :assigned_agent_id,
      :assignment_reason,
      :kb_sources,
      :agent_assist,
      :visitor_id,
      :public_token
    ])
    |> validate_required([:customer_name, :customer_email, :title, :priority, :category, :status])
    |> validate_format(:customer_email, ~r/@/)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:support_level, 1..3)
  end
end
