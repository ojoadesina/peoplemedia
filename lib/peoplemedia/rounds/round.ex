defmodule Peoplemedia.Rounds.Round do
  @moduledoc """
  One round: a person surfacing themselves, and what it is about.

  DELIBERATELY MADE, AND KEPT. It is an ACT rather than a state — the thing it
  grew out of was one row per person written over forever, which is right for
  being HERE and wrong for this. A person's page lists their past rounds; a
  pair's page interleaves every round between them. Both want rows that stay.

  ## THERE IS NOTHING ON IT

  No name, no title, no summary. Making one is somebody saying "I am here and
  open to being joined", which is the smallest true thing this app exists to let
  anybody say — and everything beyond that is said in WORDS, by whoever says it.
  A title over them would be a second summary of the thing directly underneath
  it, written before anybody had said anything.

  ## IT HAS A NUMBER, AND THAT IS WHAT IT IS KNOWN BY

  Per creator, increasing. It carried a NAME once — a forum title over the words
  beneath it — and a name is optional, repeatable, and no use to anything trying
  to point at one round. The number is none of those, so it is what a word hangs
  off and what a page lists by. The doing says what it is about.

  ## A ROUND SURFACES A PERSON. IT DOES NOT CONTAIN THE CONVERSATION.

  Which is why nothing here is a body and nothing here is a thread. The words are
  their own thing and they outlive this: expiry takes the boxes off the row and
  touches nothing else.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person

  # PUBLIC IS EVERYONE. PRIVATE IS THE PEOPLE YOU HOLD — or one of them, when a
  # target is set. Which of the two you get is decided by the tab you were
  # standing on, so nobody is asked a question the surface already knows.
  @audiences ~w(public private)

  schema "rounds" do
    belongs_to(:person, Person)
    belongs_to(:target, Person)
    # PER CREATOR, INCREASING. Names repeat and names are optional; a number is
    # neither, so it is what a word hangs off and what a page lists by.
    field(:number, :integer)
    field(:audience, :string, default: "public")
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def changeset(round, attrs) do
    round
    |> cast(attrs, [:person_id, :target_id, :audience, :expires_at, :number])
    |> validate_required([:person_id, :audience, :expires_at, :number])
    |> validate_inclusion(:audience, @audiences)
    |> unique_constraint([:person_id, :number], name: :rounds_person_id_number_index)
    # AIMING A PUBLIC ROUND IS NOT A STRICTER PUBLIC ROUND, it is two different
    # answers to one question. The database says the same; naming it here is what
    # turns its refusal into a changeset error rather than an exception.
    |> forbid_public_target()
    |> check_constraint(:target_id,
      name: :public_rounds_have_no_target,
      message: "a public round is for everyone and cannot be aimed at one person"
    )
  end

  defp forbid_public_target(changeset) do
    case {get_field(changeset, :audience), get_field(changeset, :target_id)} do
      {"public", target} when not is_nil(target) ->
        add_error(changeset, :target_id, "a public round is for everyone")

      _otherwise ->
        changeset
    end
  end

  def audiences, do: @audiences
end
