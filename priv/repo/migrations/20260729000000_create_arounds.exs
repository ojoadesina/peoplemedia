defmodule Peoplemedia.Repo.Migrations.CreateArounds do
  @moduledoc """
  BEING AROUND: are you here, and if you are, what are you doing?

  ONE ROW PER PERSON, FOREVER. This is the decision the whole feature rests on
  and it is worth stating plainly: being around is a STATE, not an event. You do
  not accumulate arounds the way you accumulate letters — you have one, and it is
  either still good or it is not.

  WHICH IS WHAT MAKES SILENT EXPIRY FREE. `expires_at` in the past means not
  around, and that is the entire mechanism: no sweep, no job, nothing to
  broadcast, and no moment at which the app announces that somebody has gone. A
  person fades out of the surface the way they faded out of the room.

  AND IT SIDESTEPS A CONSTRAINT WITH NO GOOD ANSWER. "At most one LIVE around"
  cannot be a partial unique index — Postgres will not take `now()` in an index
  predicate, because a predicate has to be immutable and the current time is the
  least immutable thing there is. One row per person is stricter, enforceable,
  and means the question never comes up.

  NO `around_id` ON LETTERS, and that was the obvious link. This row is MUTABLE:
  a letter pointing at it would silently lose the mood it was written with the
  next time the writer changed how they felt. Replies will hang off the
  LETTERHEAD; an around is the state a letterhead was written inside, not its
  parent key.

  MOOD AND ACTIVITY ARE WORDS, NOT ICONS. An icon set cannot tell `grieving`
  from `low`, and that distinction is the whole value — see `Peoplemedia.Around`
  for the two vocabularies. `about` is the one free-typed field: "watching" is
  the kind of thing, "the witchers" is the thing.

  NULL MOOD MEANS SILENT. You are around because you opened the app, and you
  have said nothing about it. That is the default and the commonest case.
  """
  use Ecto.Migration

  def change do
    create table(:arounds) do
      add :person_id, references(:people, on_delete: :delete_all), null: false
      add :mood, :string
      add :activity, :string
      add :about, :string
      add :expires_at, :utc_datetime, null: false
      timestamps()
    end

    # THE WHOLE MODEL IN ONE LINE. One person, one around.
    create unique_index(:arounds, [:person_id])
    # "Who is still here" is the list's own question, asked on every read.
    create index(:arounds, [:expires_at])

    # NOT APPEARING IS A FACT ABOUT YOU, not about one window — so it lives on
    # the person and outlives every around they ever have. On the around it would
    # expire along with the thing it was protecting, which is the one moment it
    # must not.
    #
    # PRESENCE IS AUTOMATIC AND ON, so the way out ships in the same migration
    # that ships the presence. A privacy control that arrives in the next release
    # is a privacy control that did not exist when it was needed.
    alter table(:people) do
      add :around_hidden, :boolean, null: false, default: false
    end
  end
end
