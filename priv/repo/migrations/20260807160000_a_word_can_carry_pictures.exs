defmodule Peoplemedia.Repo.Migrations.AWordCanCarryPictures do
  @moduledoc """
  A WORD CAN CARRY PICTURES, and it is the only thing on this surface that can.

  Law 5: frames are CAPTURED and words are MADE. A frame is a moment somebody
  pointed a camera at; a word is a sentence they wrote, and a sentence can have
  things attached to it — that is what "speech plus attached documents" has meant
  in the guide since the beginning, and the only place uploads are allowed.

  AN ARRAY RATHER THAN A TABLE. A word's pictures have no life of their own: they
  arrive with it, they go with it, nothing points at one, and nothing asks a
  question about pictures that is not really a question about the word. A join
  table would be four more queries to answer "are there any".
  """
  use Ecto.Migration

  def change do
    alter table(:words) do
      add :images, {:array, :string}, null: false, default: []
    end
  end
end
