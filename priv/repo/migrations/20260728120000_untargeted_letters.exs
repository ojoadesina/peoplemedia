defmodule Peoplemedia.Repo.Migrations.UntargetedLetters do
  @moduledoc """
  A LETTER MAY BE ADDRESSED TO NOBODY.

  Every letter so far hung off a relationship, because a letter was a thing that
  passed between two people. A LETTERHEAD is the other kind: written once, to a
  population rather than to a person, with nobody in particular to answer it.

  SO THE TARGET IS ONE OF TWO THINGS AND NEVER BOTH — a relationship, or an
  audience. The check constraint is that sentence, and it is in the database
  rather than only in the changeset because the changeset is one caller's
  opinion and this is a fact about the row.

  AUDIENCE IS A WORD, NOT A BOOLEAN. `is_public` would answer today's question
  and only today's: the day a third audience exists — a place, a group, one
  scope — a boolean has to be migrated and a word does not.

  AND `"world"` HERE IS NOT THE PLACE BOX'S `WORLD`. That one means EVERYWHERE
  and this one means EVERYONE; they are two different axes that happen to share
  a word, and an audience is deliberately not filtered by place.

  NO `parent_id` YET, though replies are coming. Every letter written today is a
  letterhead, because there is nothing to reply to — so the column would be NULL
  on every row in the table. When replies arrive, `parent_id IS NULL` means
  letterhead and the migration backfills nothing.
  """
  use Ecto.Migration

  def change do
    # BY HAND RATHER THAN `modify`. Ecto's modify on a column that carries a
    # reference drops and recreates the foreign key in order to change one flag,
    # which is a great deal of machinery for a NOT NULL.
    execute "ALTER TABLE letters ALTER COLUMN relationship_id DROP NOT NULL",
            "ALTER TABLE letters ALTER COLUMN relationship_id SET NOT NULL"

    alter table(:letters) do
      add :audience, :string
    end

    # `<>` is Postgres's boolean XOR: exactly one of the two is set. Spelling it
    # as a pair of IS NULL tests rather than as two separate constraints is what
    # makes it one claim — "a letter is addressed once".
    create constraint(:letters, :letters_have_one_target,
             check: "(relationship_id IS NULL) <> (audience IS NULL)"
           )

    # The self page's own query: everything I have said out loud, newest first.
    # Partial, so it costs nothing on the letters that belong to a thread.
    create index(:letters, [:sender_id, :inserted_at], where: "audience IS NOT NULL")
  end
end
