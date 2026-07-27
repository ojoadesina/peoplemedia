defmodule Peoplemedia.Repo.Migrations.CreatePassportSecrets do
  use Ecto.Migration

  # The bank of one-time secret words. Each is bcrypt-hashed; a successful
  # check-in BURNS the word it used (status active -> burned), so a shoulder-
  # surfed word is useless next time. Passport strength = active ÷ total.
  def change do
    create table(:passport_secrets) do
      add :passport_id, references(:passports, on_delete: :delete_all), null: false
      add :secret_hash, :string, null: false
      add :order, :integer, null: false
      add :status, :string, null: false, default: "active"
      add :burned_at, :utc_datetime
      timestamps()
    end

    create index(:passport_secrets, [:passport_id])
    create index(:passport_secrets, [:passport_id, :status])
  end
end
