defmodule Peoplemedia.Repo.Migrations.RoundsAreNumberedAndTyped do
  @moduledoc """
  ONE FREE-TEXT FIELD, AND A NUMBER TO KNOW IT BY.

  ## THREE TEXT FIELDS BECOME ONE

  A round carried a `name`, a closed-set `activity` and a free `about`, and the
  three overlapped: "the witchers, finally" / `movie` / "the witchers" is one
  thought said three times. The closed set was the part that had to go — a
  vocabulary of fourteen doings is either redundant beside a sentence somebody
  typed, or it is the thing stopping them saying what they actually mean.

  SO `activity` IS FREE TEXT NOW and the other two are gone. What you are doing
  is what you type. Mood keeps its closed set for the opposite reason: it is
  drawn as a COLOUR, and a colour needs a family it belongs to.

  ## AND A ROUND HAS A NUMBER

  Per creator, increasing — their first round, their second. Names repeat and
  names are optional; a number is neither, so it is what a word will hang off
  and what a person's page will list. It is a column rather than a `row_number()`
  because it must not change: your third round stays your third whatever happens
  to the ones before it, and Law 4 means nothing before it goes away.
  """
  use Ecto.Migration

  def up do
    alter table(:rounds) do
      add :number, :integer
    end

    # EXISTING ROWS KEEP THE ORDER THEY WERE MADE IN. Numbering by id rather than
    # by inserted_at because the timestamps are second-precision and a tie here
    # would hand two rounds the same number for ever.
    execute """
    UPDATE rounds SET number = seq.n
    FROM (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY id) AS n
      FROM rounds
    ) AS seq
    WHERE rounds.id = seq.id
    """

    # THE OLD NAME IS THE BEST DOING ANYBODY WROTE, so it is what survives where
    # there is one — dropping a column is dropping what people said.
    execute "UPDATE rounds SET activity = name WHERE name IS NOT NULL AND name <> ''"

    alter table(:rounds) do
      remove :name
      remove :about
    end

    # A number is required from here on; nullable only long enough to backfill.
    execute "ALTER TABLE rounds ALTER COLUMN number SET NOT NULL"
    create unique_index(:rounds, [:person_id, :number])
  end

  def down do
    drop unique_index(:rounds, [:person_id, :number])

    alter table(:rounds) do
      add :name, :string
      add :about, :string
      remove :number
    end
  end
end
