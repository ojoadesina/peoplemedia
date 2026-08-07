defmodule Peoplemedia.Repo.Migrations.Words do
  @moduledoc """
  WORDS: WHAT IS ACTUALLY SAID INSIDE A ROUND.

  A round surfaces a person and says what it is about. It has never held what
  anybody said in it — that was always going to be a thing of its own, and the
  surface has been drawing a space for it for a while: the second block of an
  item, and a count at that block's trailing edge.

  IT HANGS OFF THE ROUND, NOT OFF A RELATIONSHIP. A letter is written to a SCOPE,
  which is why a stranger's row can never carry one; a word is said in a ROUND,
  which anybody who can see the round can see. That is the whole difference
  between the two and the reason both exist.

  AND OFF A PERSON, because a round is not a monologue: the creator's own words
  and everybody else's sit in the same thread, and which is which is a fact about
  the author rather than about the round.

  THREADED, EVENTUALLY. `reply_to` is here from the start because a word is chat
  and chat is a tree — adding the column later would mean a migration under a
  live table for a shape that was known on day one. Nothing reads it yet.

  NOT NULLABLE, UNLIKE EVERYTHING ON A ROUND. A round with nothing on it is
  somebody saying "I am here"; a word with nothing in it is not a word.
  """
  use Ecto.Migration

  def change do
    create table(:words) do
      add :round_id, references(:rounds, on_delete: :delete_all), null: false
      add :person_id, references(:people, on_delete: :delete_all), null: false
      add :reply_to_id, references(:words, on_delete: :nilify_all)
      add :body, :text, null: false
      timestamps()
    end

    # THE ONE QUERY THE SURFACE MAKES: how many words are in this round, and what
    # was the last of them. Both are answered by walking a round's words in
    # order, so both want this index.
    create index(:words, [:round_id, :id])
    create index(:words, [:person_id])
  end
end
