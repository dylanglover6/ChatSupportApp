defmodule SupportBot.Repo do
  use Ecto.Repo,
    otp_app: :support_bot,
    adapter: Ecto.Adapters.Postgres
end
