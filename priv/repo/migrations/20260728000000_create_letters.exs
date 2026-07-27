defmodule Peoplemedia.Repo.Migrations.CreateLetters do
  use Ecto.Migration

  # A LETTER HANGS OFF THE RELATIONSHIP, not off a scope and not off a person.
  #
  # "A letter is written to a scope, not to a person" is the rule, and the
  # relationship is what that means once you look at the tables: a scope is
  # ONE-SIDED — mine says "MUM", hers says something else — so a thread hung off
  # one of them would be a thread only one of us could see. The relationship is
  # the shared thing, and a correspondence is shared by definition.
  #
  # `sender_id` is which of the two wrote it, and that single column is what the
  # row summary reads as direction: from me, or from them. Storing "incoming"
  # and "outgoing" instead would mean two rows, or a truth that flips depending
  # on who is asking.
  #
  # `read_at` MEANS THE RECIPIENT OPENED IT — so on a letter of theirs it is "you
  # heard it", and on one of mine it is "they heard it". One field, read from
  # whichever end you are standing at, which is what lets one row say both halves
  # of a conversation.
  def change do
    create table(:letters) do
      add :relationship_id, references(:relationships, on_delete: :delete_all), null: false
      add :sender_id, references(:people, on_delete: :delete_all), null: false
      # voice · face · text — what it arrived as. Text carries `body`; the other
      # two carry `media` and nothing else yet.
      add :kind, :string, null: false, default: "text"
      add :body, :text
      add :media, :string
      add :read_at, :utc_datetime
      timestamps()
    end

    # The thread's own query: everything on this relationship, newest first.
    create index(:letters, [:relationship_id, :inserted_at])
    # And "what is waiting for me" — everything I did not send and have not read.
    create index(:letters, [:sender_id, :read_at])
  end
end
