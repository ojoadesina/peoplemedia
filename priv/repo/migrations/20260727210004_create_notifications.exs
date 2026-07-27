defmodule Peoplemedia.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  # One generic notifications table for EVERY feature (the Laravel shape, adapted):
  # a recipient figure, an open `kind`, the acting figure, a jsonb payload, and a
  # read marker. Scoping writes the first kinds; anything later (TIME, groups,
  # chips) rides the same table. Unread badge = WHERE read_at IS NULL.
  def change do
    create table(:notifications) do
      add :person_id, references(:people, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :actor_id, references(:people, on_delete: :delete_all)
      add :data, :map, null: false, default: %{}
      add :read_at, :utc_datetime_usec

      timestamps()
    end

    create index(:notifications, [:person_id, :read_at])
    create index(:notifications, [:person_id, :inserted_at])
  end
end
