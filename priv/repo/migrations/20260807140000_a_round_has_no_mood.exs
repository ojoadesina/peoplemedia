defmodule Peoplemedia.Repo.Migrations.ARoundHasNoMood do
  @moduledoc """
  MOOD IS GONE, AND IT IS GONE FROM THE ROOT.

  A closed set of forty-eight words in seven coloured families, on the argument
  that a round should say how somebody IS as well as what they are doing. What it
  did was put a second thing to read on every block that answers one question, and
  a colour on a surface whose palette is rationed to one meaning.

  THE WORDS SAY IT NOW. A round holds what people actually said in it, and "how
  are you" was always better answered by somebody answering it than by a
  vocabulary.

  IT CAME OFF THE SURFACE FIRST, which is how a dead column survives: the boxes
  went, then the chip on the item, and the field sat on with nothing writing it
  and nothing reading it. A column nothing reads is one that gets filled in again
  by accident.
  """
  use Ecto.Migration

  def change do
    alter table(:rounds) do
      remove :mood, :string
    end
  end
end
