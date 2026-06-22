defmodule SupportBot.Repo.Migrations.CreateSupportBotTables do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :title, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false
      add :sources, {:array, :map}, default: []
      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:conversation_id])

    create table(:agents) do
      add :name, :string, null: false
      add :color, :string, null: false
      add :specialties, {:array, :string}, null: false, default: []
      add :shift_start, :time, null: false
      add :shift_end, :time, null: false
      timestamps(type: :utc_datetime)
    end

    create table(:tickets) do
      add :conversation_id, references(:conversations, on_delete: :nilify_all)
      add :customer_name, :string, null: false
      add :customer_email, :string, null: false
      add :title, :string, null: false
      add :issue_summary, :text
      add :conversation_summary, :text
      add :steps_tried, :text
      add :likely_cause, :text
      add :missing_information, :text
      add :priority, :string, null: false
      add :category, :string, null: false
      add :status, :string, null: false, default: "Open"
      add :assigned_agent_id, references(:agents, on_delete: :nilify_all)
      add :assignment_reason, :text
      add :kb_sources, {:array, :map}, default: []
      add :agent_assist, :text
      timestamps(type: :utc_datetime)
    end

    create index(:tickets, [:conversation_id])
    create index(:tickets, [:assigned_agent_id])
    create index(:tickets, [:status])

    create table(:ticket_events) do
      add :ticket_id, references(:tickets, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :message, :text, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:ticket_events, [:ticket_id])

    create table(:ticket_replies) do
      add :ticket_id, references(:tickets, on_delete: :delete_all), null: false
      add :author_name, :string, null: false
      add :body, :text, null: false
      add :reply_type, :string, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:ticket_replies, [:ticket_id])
  end
end
