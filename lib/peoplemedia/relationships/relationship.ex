defmodule Peoplemedia.Relationships.Relationship do
  @moduledoc """
  THE SHARED CONNECTION between two people, and the only thing about them that
  is not one-sided.

  `state` is the lifecycle: `scoping` while it is being asked for, `scoped` once
  both sides have agreed, and the rest are the ways it can end or pause.

  `kind` is cardinality, and there is only ONE kind here. The project this came
  from also had `zero` (your contract with yourself) and `many` (a group
  anchored to a real place on a map). Neither has anything to stand on in this
  app yet, so they are left out rather than carried as dead values.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.Relationships.Scope

  @kinds ~w(one)
  @states ~w(scoping scoped rescoping paused frozen blocked unscoped expired)

  schema "relationships" do
    field(:kind, :string)
    field(:state, :string, default: "scoping")

    has_many(:scopes, Scope)

    timestamps()
  end

  def changeset(rel, attrs) do
    rel
    |> cast(attrs, [:kind, :state])
    |> validate_required([:kind, :state])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:state, @states)
  end
end
