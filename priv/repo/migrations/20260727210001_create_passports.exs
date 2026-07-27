defmodule Peoplemedia.Repo.Migrations.CreatePassports do
  use Ecto.Migration

  # A PASSPORT IS THE AUTH RECORD for a person who actually signs in. It hangs
  # off a `people` row rather than replacing it, so the great majority of people
  # here — everyone who exists only because someone scoped them — simply have no
  # passport, and the list can be read without going anywhere near auth.
  #
  # NOTHING SECRET LIVES IN `people`. The hashed code is here, the hashed word
  # bank is in a child table, and both are behind a join no query about names
  # will ever make by accident.
  #
  # THE ATTEMPT COUNTERS ARE SEPARATE AND THE LOCKOUT IS SHARED. Sign-in is two
  # steps — word, then code — and a brute force against either one has to be
  # counted on its own or the cheaper step masks the other. The lock they both
  # write to is one window, because a locked passport is locked.
  def change do
    create table(:passports) do
      add :person_id, references(:people, on_delete: :delete_all), null: false
      # The 4-digit code, bcrypt-hashed (the constant second factor).
      add :code_hash, :string, null: false
      # Health of the word-bank: active ÷ total × 100. Drops as words are burned.
      add :strength, :integer, null: false, default: 100
      # Brute-force guards: separate attempt counters + a shared lockout window.
      add :key_attempts, :integer, null: false, default: 0
      add :code_attempts, :integer, null: false, default: 0
      add :locked_until, :utc_datetime
      timestamps()
    end

    create unique_index(:passports, [:person_id])
  end
end
