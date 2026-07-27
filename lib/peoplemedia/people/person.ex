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

    timestamps()
  end

  def changeset(person, attrs) do
    person
    |> cast(attrs, [:name, :country])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 60)
  end
end
