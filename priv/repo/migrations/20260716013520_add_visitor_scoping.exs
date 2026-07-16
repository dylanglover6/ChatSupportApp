defmodule SupportBot.Repo.Migrations.AddVisitorScoping do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :visitor_id, :string
    end

    alter table(:tickets) do
      add :visitor_id, :string
    end

    create index(:conversations, [:visitor_id])
    create index(:tickets, [:visitor_id])
  end
end
