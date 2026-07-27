defmodule Peoplemedia.Release do
  @moduledoc """
  Database tasks for a running RELEASE, where Mix does not exist.

  `mix ecto.migrate` is a build-time tool; a release ships compiled beams and no
  Mix, so production migrations have to be a function the release can call. The
  `bin/migrate` overlay is what Fly's deploy hook runs.
  """
  @app :peoplemedia

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Migrate, then seed. What the deploy runs.

  SEEDING PRODUCTION ON EVERY DEPLOY is deliberate while the app is a demo of
  itself: the list has to have people in it for the surface to be worth looking
  at, and `priv/repo/seeds.exs` is idempotent — everyone is found by name before
  they are created, so running it a hundred times adds nobody.

  TAKE THE SEED OUT OF THIS the day real people have passports. An idempotent
  seed is harmless but it is not free: it keeps a demo cast alive in a database
  that has stopped being a demo, and nobody will remember why they are there.
  """
  def setup do
    migrate()
    seed()
  end

  def seed do
    load_app()
    path = Application.app_dir(@app, "priv/repo/seeds.exs")

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _ -> Code.eval_file(path) end)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    # Managed Postgres requires SSL, and :ssl has to be up before the pool tries
    # to connect — a release does not start it for you.
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
