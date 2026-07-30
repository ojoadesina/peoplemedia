defmodule Peoplemedia.Repo.Migrations.CreateRounds do
  @moduledoc """
  A ROUND, and the splitting of the thing that came before it.

  `arounds` held two ideas in one row and the second one has outgrown it. Being
  HERE is a state — one per person, written over, and the reason expiry could be
  a comparison rather than a job. Going ROUND is an ACT: deliberately made, kept
  forever, and made again the next time rather than edited.

  SO THEY BECOME TWO TABLES, and the old one keeps the half it was right about.
  `arounds` loses its mood, its doing and its words and becomes `presences`:
  person, and until when. Everything else moves here.

  ## ROUNDS ACCUMULATE

  ONE ROW PER ROUND, NOT PER PERSON, and the unique index that made the old
  model work is exactly what has to go. A person's page lists their past rounds
  under their latest; a pair's page interleaves every round between them. Neither
  is possible against a row that is written over — and Law 4 is that expiry is
  about VISIBILITY, never deletion.

  GOING ROUND AGAIN IS A NEW ROW. An expired round does not come back, so there
  is nothing to revive and no state to reconcile: the old one keeps its words and
  its place in the history, and the new one is simply newer.

  ## EVERYTHING ON IT IS OPTIONAL

  A round works with or without a name, a frame, a mood and a doing. All four
  nullable is not laxness — a round with nothing on it is a person saying "I am
  here and open to being joined", which is the smallest true thing this app
  exists to let somebody say.

  ## WHO IT IS FOR

  `audience` is `public` or `private`, and `target_id` is what private MEANS:
  set, and it is for that one person; null, and it is for everyone you hold. The
  tab you are standing on decides it, so nobody is ever asked.

  ## EXPIRY IS THE CREATOR'S ALONE

  Forty-five minutes after the CREATOR goes quiet — not the last person to say
  something. A round is somebody surfacing themselves, so it lasts as long as
  they are the one still there. And expiry takes the name and the boxes off the
  row and nothing else: the words go on, the notifications go on, and nobody is
  ever told that it happened. Absence is silent.
  """
  use Ecto.Migration

  def change do
    create table(:rounds) do
      add :person_id, references(:people, on_delete: :delete_all), null: false
      # A forum title, and capped in the changeset. Optional, like everything.
      add :name, :string
      add :mood, :string
      add :activity, :string
      add :about, :string
      add :audience, :string, null: false, default: "public"
      # PRIVATE TO ONE PERSON when set; private to everyone you hold when not.
      # A public round has no target and could not use one.
      add :target_id, references(:people, on_delete: :nilify_all)
      add :expires_at, :utc_datetime, null: false
      timestamps()
    end

    # THE LIST'S OWN QUESTION: whose round is the newest. The homepage sorts by
    # it and a person's page reads their own history down the same index.
    create index(:rounds, [:person_id, :inserted_at])
    # "Is anybody still round" — asked on every read of every list.
    create index(:rounds, [:expires_at])
    # What a private round to one person is answered by, from their side.
    create index(:rounds, [:target_id])

    # A PUBLIC ROUND IS FOR EVERYONE, so aiming it at somebody is not a stricter
    # public round, it is two different answers to one question. The database
    # says so because the changeset is one caller's opinion and this is a fact
    # about the row.
    create constraint(:rounds, :public_rounds_have_no_target,
             check: "audience = 'private' OR target_id IS NULL"
           )

    # ── AND WHAT IS LEFT OF `arounds` IS PRESENCE ────────────────────────────
    # It was already the right shape for it: one row per person, upserted,
    # expiring by comparison. Only the columns that turned out to belong to an
    # ACT rather than to a STATE come off.
    rename table(:arounds), to: table(:presences)

    alter table(:presences) do
      remove :mood, :string
      remove :activity, :string
      remove :about, :string
    end
  end
end
