defmodule Peoplemedia.Repo.Migrations.CreateScopes do
  use Ecto.Migration

  # A SCOPE IS ONE PERSON'S ONE-SIDED LABELLING of the other side. You scoping
  # Sarah as "MUM" creates YOUR row and nothing of hers — she still sees you by
  # your own name until she scopes back. That asymmetry is the whole model, and
  # it is why the label cannot live on the relationship.
  #
  # This is also exactly what the list has been drawing all along: `name` is the
  # label the row leads with, and the person's own name comes from `people`.
  def change do
    create table(:scopes) do
      add :relationship_id, references(:relationships, on_delete: :delete_all), null: false
      add :owner_id, references(:people, on_delete: :delete_all), null: false
      add :target_id, references(:people, on_delete: :delete_all)
      add :name, :string, null: false
      add :type, :string, null: false
      add :terms, :map, null: false, default: %{}
      timestamps()
    end

    # ONE SCOPE PER PERSON PER RELATIONSHIP. Without this the handshake could
    # write a second row for the same side on a retry, and a relationship would
    # have two answers to "what does he call her".
    create unique_index(:scopes, [:relationship_id, :owner_id])
    # The list's own query: everyone I have scoped.
    create index(:scopes, [:owner_id, :target_id])
    # And the other direction, for "who has scoped me".
    create index(:scopes, [:target_id])
  end
end
