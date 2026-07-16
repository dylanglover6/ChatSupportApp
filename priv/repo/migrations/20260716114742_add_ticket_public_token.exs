defmodule SupportBot.Repo.Migrations.AddTicketPublicToken do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add :public_token, :string
    end

    # Backfill existing rows with a random token so the unique index can be created.
    execute(
      "UPDATE tickets SET public_token = md5(random()::text || clock_timestamp()::text || id::text) WHERE public_token IS NULL",
      ""
    )

    create unique_index(:tickets, [:public_token])
  end
end
