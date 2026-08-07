defmodule Peoplemedia.Repo.Migrations.ARoundIsKnownByWhenItWasMade do
  @moduledoc """
  A ROUND HAS NO NAME, AND NEEDS NONE.

  It had three text fields once — a `name`, a closed-set `activity` and a free
  `about` — which collapsed into one, `doing`, on the argument that "the witchers,
  finally" said three times is once too many. This is the same argument taken to
  its end: it is said ONCE, and not by the round at all.

  WHAT A ROUND IS FOR IS WHAT IS SAID IN IT. The words are there now, and the
  first of them arrives in the same press that makes the round. A title over them
  is a second summary of the thing directly underneath it, written by somebody who
  had not said anything yet — the least informed sentence in the round, given the
  most prominent line of it.

  IT IS KNOWN BY WHEN IT WAS MADE. `inserted_at` is already on the row, already
  unique enough per person for anything that has to point at one, and cannot go
  stale the way a title given before the fact can. The `number` stays for the same
  reason it always did: your third round is your third whatever happens to the
  ones before it.

  `name` GOES TOO — the nullable column kept ready for exactly this field, which
  nothing ever wrote to.
  """
  use Ecto.Migration

  def change do
    alter table(:rounds) do
      remove :doing, :string
      remove :name, :string
    end
  end
end
