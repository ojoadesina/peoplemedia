defmodule Peoplemedia.Words.Word do
  @moduledoc """
  One word: something somebody said inside a round.

  A WORD IS MADE, NOT CAPTURED — Law 5, and it is the whole of what separates
  this from a frame. A frame is a moment somebody pointed a camera or a
  microphone at; a word is a sentence they wrote. Nothing here is a file.

  IT BELONGS TO A ROUND AND OUTLIVES IT. Expiry takes the round off the surface
  and touches nothing here: "a round surfaces a person, it does not contain the
  conversation." The words stay, and a person's page can walk back through them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person
  alias Peoplemedia.Rounds.Round

  # SHORT, AND SHORTER THAN A LETTER. A letter is a thing you sit down to write;
  # a word is said into a room somebody is standing in. The surface shows it on
  # ONE LINE — a block of the item, truncating — so anything longer than this is
  # a paragraph nobody will read at the size it is drawn.
  @limit 280

  schema "words" do
    belongs_to(:round, Round)
    belongs_to(:person, Person)
    belongs_to(:reply_to, __MODULE__)
    field(:body, :string)

    timestamps()
  end

  def changeset(word, attrs) do
    word
    |> cast(attrs, [:round_id, :person_id, :reply_to_id, :body])
    |> validate_required([:round_id, :person_id, :body])
    |> update_change(:body, &String.trim/1)
    # AN EMPTY WORD IS NOT A QUIET WORD, it is a press that should not have
    # landed. Everything on a ROUND is optional because a round with nothing on
    # it still says "I am here"; a word with nothing in it says nothing at all.
    |> validate_length(:body, min: 1, max: @limit)
  end

  def limit, do: @limit
end
