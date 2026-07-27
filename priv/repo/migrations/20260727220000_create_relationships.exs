defmodule Peoplemedia.Repo.Migrations.CreateRelationships do
  use Ecto.Migration

  # THE SHARED CONNECTION between two people, and the only thing about them that
  # is not one-sided. `kind` is its cardinality and `state` its lifecycle: a
  # relationship is `scoping` while it is being asked for and `scoped` once both
  # sides have agreed.
  #
  # THE LABELS ARE NOT HERE. What you call someone lives on your own scope, in
  # the next table — "MUM" is not a fact about Sarah, it is a fact about your
  # relationship with Sarah, and she may well call you something else.
  #
  # NO `landmark_id` AND NO `many`. The project this came from anchored group
  # relationships to real places on a world map; there are no places here finer
  # than a country and no groups yet, so the column and the kind are left out
  # rather than carried empty.
  def change do
    create table(:relationships) do
      add :kind, :string, null: false, default: "one"
      add :state, :string, null: false, default: "scoping"
      timestamps()
    end

    create index(:relationships, [:state])
  end
end
