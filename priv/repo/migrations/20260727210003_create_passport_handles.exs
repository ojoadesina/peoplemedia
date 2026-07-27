defmodule Peoplemedia.Repo.Migrations.CreatePassportHandles do
  use Ecto.Migration

  # The public nickname(s). `handle_code` is the normalised (lower-cased) unique
  # key used for sign-in lookup and (later) search-by-handle. Kept as its own
  # table — with a status — so a future rename can retire an old handle without
  # losing history or freeing it instantly.
  def change do
    create table(:passport_handles) do
      add :passport_id, references(:passports, on_delete: :delete_all), null: false
      add :handle_code, :string, null: false
      add :status, :string, null: false, default: "active"
      timestamps()
    end

    create unique_index(:passport_handles, [:handle_code])
    create index(:passport_handles, [:passport_id])
  end
end
