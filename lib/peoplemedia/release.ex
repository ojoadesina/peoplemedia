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
