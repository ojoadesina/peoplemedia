defmodule Peoplemedia.Relationships.Scope do
  @moduledoc """
  ONE PERSON'S ONE-SIDED LABELLING of the other side of a relationship.

  Owned by `owner_id`, hanging off a `Relationship`. Scopes are one-sided: you
  scoping Sarah as "MUM" creates YOUR row and nothing of hers — she still sees
  you by your own name until she scopes back. That asymmetry is the whole model,
  and it is why the label cannot live on the relationship.

  `name` is what the owner calls the target, and it is the word the list leads
  each row with. `type` is the role the system assigned. `terms` is whatever
  else the owner has to say about it, and is deliberately open.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.Relationships.Relationship
  alias Peoplemedia.People.Person

  schema "scopes" do
    belongs_to(:relationship, Relationship)
    belongs_to(:owner, Person)
    belongs_to(:target, Person)
    field(:name, :string)
    field(:type, :string)
    field(:terms, :map, default: %{})

    timestamps()
  end

  def changeset(scope, attrs) do
    scope
    |> cast(attrs, [:relationship_id, :owner_id, :target_id, :name, :type, :terms])
    |> validate_required([:relationship_id, :owner_id, :name, :type])
    |> unique_constraint([:relationship_id, :owner_id])
  end
end
