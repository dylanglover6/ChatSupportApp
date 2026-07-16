defmodule SupportBot.Release do
  @moduledoc "Tasks callable via `bin/support_bot eval` — releases have no Mix at runtime."

  @app :support_bot

  def migrate do
    for repo <- repos(), do: {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  def seed do
    for repo <- repos() do
      Ecto.Migrator.with_repo(repo, fn _repo ->
        Code.eval_file(Path.join(:code.priv_dir(@app), "repo/seeds.exs"))
      end)
    end
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)
end
