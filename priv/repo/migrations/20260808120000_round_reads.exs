defmodule Peoplemedia.Repo.Migrations.RoundReads do
  @moduledoc """
  HOW FAR INTO A ROUND SOMEBODY HAS GOT.

  The count on an item lights while there is something in there you have not seen,
  and until now it lit off an unopened LETTER — a fact about a correspondence
  standing in for a fact about a round, which is why a stranger's row could never
  light however much was said in front of them.

  A MARK PER PERSON PER ROUND, because a word is not read the way a letter is: a
  letter has one recipient and can carry its own `read_at`, and a round is a room
  anybody who can see it may be standing in. Whether YOU have seen what is in it
  is a fact about the pair of you and belongs on neither end alone.

  `seen_id`, NOT A TIMESTAMP. `timestamps()` is second-precision and two words
  said in one second would collapse into "both seen" or "neither" — the same trap
  `last_round_for/2` avoids by ordering on `max(id)`. The highest word id you have
  seen is exact and cannot tie.

  NO ROW MEANS NONE SEEN, which is the resting state and the commonest one, so it
  is the one that costs nothing to store.
  """
  use Ecto.Migration

  def change do
    create table(:round_reads) do
      add :person_id, references(:people, on_delete: :delete_all), null: false
      add :round_id, references(:rounds, on_delete: :delete_all), null: false
      add :seen_id, :integer, null: false
      timestamps()
    end

    create unique_index(:round_reads, [:person_id, :round_id])
  end
end
