defmodule Peoplemedia.People.Person do
  @moduledoc """
  A person. Everyone in the app is one of these — the people you hold and the
  people you do not.

  IT CARRIES ALMOST NOTHING, and that is the design. A name, and where in the
  world they are. What you CALL them is not here: "MUM" is not a fact about
  Sarah, it is a fact about your relationship with Sarah, and it lives on the
  scope that joins you. Two people can call the same person different things and
  both be right.

  Auth is not here either. A passport hangs off this row in its own table, so a
  person can exist with no way to sign in — which is the normal case, since most
  people here exist because somebody scoped them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "people" do
    field(:name, :string)
    field(:country, :string)
    # WHETHER THEY APPEAR AT ALL. Being around is automatic — opening the app is
    # the whole gesture — so the way out has to be a standing fact about the
    # person rather than a choice made per session. On the around itself it would
    # expire along with the thing it was protecting, which is the one moment it
    # must not. See `Peoplemedia.Around`, which is the only place it is read.
    field(:around_hidden, :boolean, default: false)
    # STANDING, AND NOT AN INVITATION. A round is made and expires; this simply
    # is. See the migration for why the two can share a block without being
    # mistaken for one another.
    field(:status, :string)
    # WHAT THEY CAPTURED OF THEMSELVES — a face, a voice or a still. Theirs, and
    # the same whoever is looking, which is why it hangs off the person rather
    # than off a correspondence. See the migration.
    field(:capture_kind, :string)
    field(:capture, :string)

    timestamps()
  end

  def changeset(person, attrs) do
    person
    |> cast(attrs, [:name, :country, :status, :capture_kind, :capture])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 60)
  end

  @doc "Appear, or do not. The one thing on this row that is a preference."
  def around_changeset(person, attrs) do
    cast(person, attrs, [:around_hidden])
  end
end
