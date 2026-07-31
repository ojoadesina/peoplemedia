defmodule Peoplemedia.Repo.Migrations.ARoundHasADoing do
  @moduledoc """
  `activity` IS CALLED `doing`, AND THE MERGE IS DONE AT THE ROOT.

  The column was named when a doing was a closed category — `movie`, `cooking`,
  one of fourteen — and a separate free line said which movie. Both of those
  collapsed into one typed sentence, and `activity` is the old shape's word for
  it: a category, a kind of thing. What a round carries is what somebody is
  DOING, said in their own words, so that is what the column is called.

  IT WAS PATCHED IN PLACE FIRST, which is how the name survived the change it
  was already wrong for. Renaming at the root is the difference between a schema
  that says what it holds and one that says what it used to.

  `name` COMES BACK, NULLABLE AND UNUSED. It was dropped when the doing absorbed
  it, and the guide still calls a round's title a name — nothing writes one
  today, and a column standing ready costs nothing next to a migration under a
  live table when it turns out one is wanted.
  """
  use Ecto.Migration

  def change do
    rename table(:rounds), :activity, to: :doing

    alter table(:rounds) do
      add :name, :string
    end
  end
end
