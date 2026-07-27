defmodule Peoplemedia.Repo.Migrations.CreatePeople do
  use Ecto.Migration

  # EVERYONE IS A PERSON ROW — the ones you hold and the ones you do not. A
  # scope is what makes someone yours, and it is a row joining two of these; a
  # stranger is simply a person you have no scope on. Keeping strangers out of
  # this table would make the UNSCOPED list unqueryable and leave swipe-to-scope
  # with nothing to scope.
  #
  # A PASSPORT IS OPTIONAL, and that is the point of the split. Most people here
  # will never sign in — they are someone else's mother, and the app knows them
  # because they were scoped, not because they arrived. Auth hangs off this row
  # in its own tables, so a person can exist with no way to log in and no secrets
  # can leak through a query that only wanted a name.
  #
  # COUNTRY, AND NOTHING FINER. The app it was ported from carried hilbert
  # positions, landmarks, cities and visits; this one asks where in the world you
  # are and stops there.
  def change do
    create table(:people) do
      add :name, :string, null: false
      add :country, :string
      timestamps()
    end

    # The list is a roll of people in a place, so this is the shape it reads by.
    create index(:people, [:country])
  end
end
