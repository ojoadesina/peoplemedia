defmodule Peoplemedia.Repo.Migrations.LettersBecomeWords do
  use Ecto.Migration

  @moduledoc """
  THE LETTERS TABLE GOES, AND THE STANDING STATUS WITH IT.

  A LETTER WAS A THING WRITTEN TO A RELATIONSHIP, and this app does not have one
  any more. What passes between people is WORDS, and a word is said inside a
  ROUND — which is a different shape, not a rename: a letter had one recipient
  and a private thread, a word is said in a room somebody is standing in and
  everybody in the audience can read it. `words` has carried that since
  20260807120000; `letters` has been the surface's second, dead vocabulary ever
  since, and two names for what a person said is one name too many.

  AND `people.status` GOES BECAUSE NOTHING WROTE IT BUT THE SEEDS. It was what
  somebody was up to when they were not round — a standing line drawn in the
  item's second block. That block is a WORD now and only ever a word, so a status
  drawn there read as something the person had said when it was nothing of the
  kind: no round, no words, no block.

  IT IS A DROP, AND LAW 4 DOES NOT REACH IT. Expiry is about visibility and never
  deletion — that is a rule about what the app does to a person's own acts while
  they are using it. This is the schema losing a table nothing writes to and no
  surface reads; the rows in it were fixture and seed correspondence.

  DOWN REBUILDS THE SHAPE AND NOT THE CONTENT, which is all a down can honestly
  promise here.
  """
  def up do
    drop table(:letters)
    alter table(:people), do: remove(:status)
  end

  def down do
    alter table(:people), do: add(:status, :string)

    create table(:letters) do
      add :relationship_id, references(:relationships, on_delete: :delete_all)
      add :sender_id, references(:people, on_delete: :delete_all), null: false
      add :audience, :string
      add :kind, :string, null: false, default: "text"
      add :body, :text
      add :media, :string
      add :read_at, :utc_datetime
      timestamps()
    end

    create index(:letters, [:relationship_id, :inserted_at])
    create index(:letters, [:sender_id, :read_at])
  end
end
