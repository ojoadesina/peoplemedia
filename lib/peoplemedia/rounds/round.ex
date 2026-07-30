defmodule Peoplemedia.Rounds.Round do
  @moduledoc """
  One round: a person surfacing themselves, and what it is about.

  DELIBERATELY MADE, AND KEPT. It is an ACT rather than a state — the thing it
  grew out of was one row per person written over forever, which is right for
  being HERE and wrong for this. A person's page lists their past rounds; a
  pair's page interleaves every round between them. Both want rows that stay.

  ## EVERYTHING ON IT IS OPTIONAL

  Name, mood, doing, and the thing the doing is about. All four nullable, and
  that is the design rather than laxness: a round with nothing on it is somebody
  saying "I am here and open to being joined", which is the smallest true thing
  this app exists to let anybody say. Filling it in is how you say more.

  ## THE NAME IS A TITLE, NOT A LETTER

  It behaves the way a forum topic does — short, capped, and the thing the words
  underneath are about. What used to be written here was a LETTERHEAD, which was
  a letter addressed to nobody; the round's own name does that job now and does
  it better, because a topic that surfaces a person is a different object from a
  letter with no recipient.

  ## A ROUND SURFACES A PERSON. IT DOES NOT CONTAIN THE CONVERSATION.

  Which is why nothing here is a body and nothing here is a thread. The words are
  their own thing and they outlive this: expiry takes the name and the boxes off
  the row and touches nothing else.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person

  # ── HOW YOU ARE ─────────────────────────────────────────────────────────────
  # WORDS, NOT PICTURES, and the size of this list is the argument. `heartbroken`
  # and `disappointed` are different things and no pair of icons reliably says
  # which is which; drawn as faces they collapse into the same face, which is
  # exactly the distinction worth showing.
  #
  # SEVEN FAMILIES, AND THE FAMILY CARRIES THE COLOUR. One colour per mood would
  # be forty-eight hues nobody could learn; one per family is seven, and inside a
  # family the words differ by INTENSITY — annoyed, irritated, furious — so the
  # colour tells you the weather and the word tells you the temperature.
  @mood_families [
    {"joy", ~w(happy cheerful excited amused proud relieved grateful hopeful)},
    {"calm", ~w(calm content relaxed steady peaceful rested satisfactory)},
    {"love", ~w(loving caring adoring missing thankful soft)},
    {"anger", ~w(angry furious annoyed irritated frustrated bitter jealous done)},
    {"sorrow", ~w(sad lonely empty miserable heartbroken ashamed disappointed sorry)},
    {"flat", ~w(tired bored meh numb lazy sleepy sick exhausted)},
    {"fear", ~w(restless anxious nervous unsure overwhelmed scared)}
  ]

  @moods Enum.flat_map(@mood_families, fn {_family, words} -> words end)
  @family_of @mood_families
             |> Enum.flat_map(fn {family, words} -> Enum.map(words, &{&1, family}) end)
             |> Map.new()

  # WHAT KIND OF THING, not what thing. A simple category, deliberately small —
  # `out` is the honest catch-all and `about` carries the rest.
  @activities ~w(food travelling rest movie reading listening cooking walking
                 working studying training playing making out)

  # PUBLIC IS EVERYONE. PRIVATE IS THE PEOPLE YOU HOLD — or one of them, when a
  # target is set. Which of the two you get is decided by the tab you were
  # standing on, so nobody is asked a question the surface already knows.
  @audiences ~w(public private)

  # A TITLE, NOT A PAGE. Long enough for "trying to fix the bike before it rains"
  # and short enough to sit on a row without truncating into nonsense.
  @name_limit 80

  schema "rounds" do
    belongs_to(:person, Person)
    belongs_to(:target, Person)
    field(:name, :string)
    field(:mood, :string)
    field(:activity, :string)
    field(:about, :string)
    field(:audience, :string, default: "public")
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def changeset(round, attrs) do
    round
    |> cast(attrs, [
      :person_id,
      :target_id,
      :name,
      :mood,
      :activity,
      :about,
      :audience,
      :expires_at
    ])
    |> validate_required([:person_id, :audience, :expires_at])
    |> validate_inclusion(:audience, @audiences)
    |> validate_inclusion(:mood, @moods)
    |> validate_inclusion(:activity, @activities)
    |> validate_length(:name, max: @name_limit)
    # SHORT BY CONSTRUCTION. It rides in a box beside the band; a sentence set
    # there would either overrun the rail or truncate into nonsense.
    |> validate_length(:about, max: 60)
    # A THING WITH NO KIND OF THING IS NOT AN ANSWER. "The witchers" alone does
    # not say whether you are watching it, reading it or arguing about it.
    |> require_activity_for_about()
    # AIMING A PUBLIC ROUND IS NOT A STRICTER PUBLIC ROUND, it is two different
    # answers to one question. The database says the same; naming it here is what
    # turns its refusal into a changeset error rather than an exception.
    |> forbid_public_target()
    |> check_constraint(:target_id,
      name: :public_rounds_have_no_target,
      message: "a public round is for everyone and cannot be aimed at one person"
    )
  end

  defp require_activity_for_about(changeset) do
    case {get_field(changeset, :about), get_field(changeset, :activity)} do
      {about, nil} when is_binary(about) and about != "" ->
        add_error(changeset, :activity, "say what you are doing with it")

      _otherwise ->
        changeset
    end
  end

  defp forbid_public_target(changeset) do
    case {get_field(changeset, :audience), get_field(changeset, :target_id)} do
      {"public", target} when not is_nil(target) ->
        add_error(changeset, :target_id, "a public round is for everyone")

      _otherwise ->
        changeset
    end
  end

  def moods, do: @moods
  def activities, do: @activities
  def audiences, do: @audiences
  def name_limit, do: @name_limit

  @doc """
  The moods, in their families and in order — `[{family, words}]`.

  A LIST AND NOT A MAP, because the order is part of the answer. The families run
  warm to cold and the words inside each run mild to strong, which is what makes
  a grid of forty-eight readable at all: you find the weather first and the
  temperature second.
  """
  def mood_families, do: @mood_families

  @doc """
  Which family a mood belongs to, or nil. The COLOUR hangs off this rather than
  off the mood itself — one hue per family is seven to learn, one per mood would
  be forty-eight nobody could.
  """
  def family_of(nil), do: nil
  def family_of(mood), do: Map.get(@family_of, mood)
end
