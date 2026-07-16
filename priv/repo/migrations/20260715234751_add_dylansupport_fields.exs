defmodule SupportBot.Repo.Migrations.AddDylansupportFields do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :expertise_level, :integer, null: false, default: 1
    end

    alter table(:tickets) do
      add :support_level, :integer, null: false, default: 1
      add :urgent, :boolean, null: false, default: false
    end

    execute "UPDATE tickets SET status = 'New' WHERE status = 'Open'",
            "UPDATE tickets SET status = 'Open' WHERE status = 'New'"

    execute "UPDATE tickets SET status = 'Resolved' WHERE status = 'Waiting on Customer'",
            ""

    alter table(:ticket_replies) do
      add :kind, :string, null: false, default: "note"
      add :email_to, :string
      add :email_subject, :string
    end

    execute "UPDATE ticket_replies SET kind = 'email' WHERE reply_type = 'agent_reply'",
            ""
    execute "UPDATE ticket_replies SET kind = 'note' WHERE reply_type = 'internal_note'",
            ""

    alter table(:ticket_replies) do
      remove :reply_type, :string
    end

    alter table(:conversations) do
      add :agent_active, :boolean, null: false, default: false
      add :active_agent_name, :string
    end
  end
end
