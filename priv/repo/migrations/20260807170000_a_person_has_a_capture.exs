defmodule Peoplemedia.Repo.Migrations.APersonHasACapture do
  @moduledoc """
  A CAPTURE BELONGS TO THE PERSON, NOT TO THE CORRESPONDENCE.

  The frame beside the band drew whatever the last LETTER carried, which made a
  capture of somebody a property of what had passed between the two of you. It
  meant a stranger's frame was empty by definition — a letter is written to a
  SCOPE, so people you do not hold have none and never will — and most of the
  column showed nothing at all. The two states hardest to judge were the two
  almost nobody could see.

  A FACE IS WHAT SOMEBODY CAPTURED OF THEMSELVES. It is theirs, it is the same
  whoever is looking, and it has nothing to do with whether you have written to
  each other. So it hangs off the person.

  KIND AND FILE, BOTH NULLABLE, because having captured nothing is the resting
  state and the commonest one. `face`, `voice`, `still` — the frame's own three,
  which are not the letter's three and never were.
  """
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :capture_kind, :string
      add :capture, :string
    end
  end
end
