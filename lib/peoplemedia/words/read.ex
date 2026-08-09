defmodule Peoplemedia.Words.Read do
  @moduledoc """
  How far into one round one person has got. See the migration for why this is a
  row of its own rather than a column on either end.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person
  alias Peoplemedia.Rounds.Round

  schema "round_reads" do
    belongs_to(:person, Person)
    belongs_to(:round, Round)
    # THE HIGHEST WORD ID SEEN, so "unseen" is `id > seen_id` — exact, and unable
    # to tie the way a second-precision timestamp can.
    field(:seen_id, :integer)

    timestamps()
  end

  def changeset(read, attrs) do
    read
    |> cast(attrs, [:person_id, :round_id, :seen_id])
    |> validate_required([:person_id, :round_id, :seen_id])
    |> unique_constraint([:person_id, :round_id])
  end
end
