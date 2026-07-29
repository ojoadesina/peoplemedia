defmodule Peoplemedia.Around.Around do
  @moduledoc """
  One person's around: are they here, and what are they doing?

  A STATE, NOT AN EVENT. There is one of these per person and it is upserted
  forever — see the migration for why that is what makes silent expiry free.

  SILENT IS THE DEFAULT AND THE COMMONEST CASE. `mood` and `activity` are both
  nil for somebody who simply opened the app, and that is a complete around: they
  are here, and they have not said anything about it. Going LOUD fills them in.

  `about` IS THE ONLY THING ANYBODY TYPES. The two vocabularies are closed
  because the surface has to be scannable — `WATCHING` repeating down a column is
  legible at a glance and eleven people's freely-typed doings are not — and the
  specificity that closing them costs comes back here, and in the letter. The
  kind of thing is `watching`; the thing is `the witchers`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person

  # ── HOW YOU ARE ─────────────────────────────────────────────────────────────
  # WORDS, NOT PICTURES, and the size of this list is the argument. `heartbroken`
  # and `disappointed` are different things and no pair of icons reliably says
  # which is which; drawn as faces they collapse into the same face, which is
  # exactly the distinction worth showing. Forty-eight is also more marks than
  # this surface's whole vocabulary — every glyph here is one rectangle cut three
  # ways.
  #
  # SEVEN FAMILIES, AND THE FAMILY CARRIES THE COLOUR. Vent's lesson, taken and
  # muted: it grouped feelings by hue and let the WORD do the precision, which is
  # the only way a set this size stays scannable. One colour per mood would be
  # forty-eight hues nobody could learn; one per family is seven, and inside a
  # family the words differ by INTENSITY — annoyed, irritated, furious — so the
  # colour tells you the weather and the word tells you the temperature.
  #
  # THE HUES ARE NOT VENT'S. Theirs are saturated and shout, which suits an app
  # whose subject is venting; every ramp here is desaturated and this one sits at
  # roughly primary-500's saturation so it reads as part of the same hand. See
  # app.css for the values and for why none of them reaches full strength.
  @mood_families [
    {"joy", ~w(happy cheerful excited amused proud relieved grateful hopeful)},
    {"calm", ~w(calm content relaxed steady peaceful rested)},
    {"love", ~w(loving caring adoring missing thankful soft)},
    {"anger", ~w(angry furious annoyed irritated frustrated bitter jealous done)},
    {"sorrow", ~w(sad lonely empty miserable heartbroken ashamed disappointed sorry)},
    {"flat", ~w(tired bored meh numb lazy sleepy sick exhausted)},
    {"fear", ~w(restless anxious nervous unsure overwhelmed scared)}
  ]

  @moods Enum.flat_map(@mood_families, fn {_family, words} -> words end)
  @family_of Map.new(@mood_families, fn {family, words} -> {family, words} end)
             |> Enum.flat_map(fn {family, words} -> Enum.map(words, &{&1, family}) end)
             |> Map.new()

  # WHAT KIND OF THING, not what thing. The set stays small enough to scan and
  # deliberately does not try to name every human activity — `out` is the honest
  # catch-all, and `about` carries the rest.
  @activities ~w(watching reading listening eating cooking walking travelling
                 working studying training playing making resting out)

  schema "arounds" do
    belongs_to(:person, Person)
    field(:mood, :string)
    field(:activity, :string)
    field(:about, :string)
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  @doc "The silent one: here, and saying nothing about it."
  def touch_changeset(around, attrs) do
    around
    |> cast(attrs, [:person_id, :expires_at])
    |> validate_required([:person_id, :expires_at])
  end

  @doc """
  The loud one: a mood, a doing, and the specific thing.

  ALL THREE ARE OPTIONAL SEPARATELY. A mood with no activity is a complete
  sentence — "I am here and I am low" — and demanding both would make the
  quieter half of the feature unreachable.
  """
  def speak_changeset(around, attrs) do
    around
    |> cast(attrs, [:person_id, :mood, :activity, :about, :expires_at])
    |> validate_required([:person_id, :expires_at])
    |> validate_inclusion(:mood, @moods)
    |> validate_inclusion(:activity, @activities)
    # SHORT BY CONSTRUCTION. It rides in a box beside the band at the count's
    # type size; a sentence set there would either overrun the rail or be
    # truncated into nonsense. The letter is where length belongs.
    |> validate_length(:about, max: 60)
    # A THING WITH NO KIND OF THING IS NOT AN ANSWER. "The witchers" alone does
    # not say whether you are watching it, reading it or arguing about it.
    |> require_activity_for_about()
  end

  defp require_activity_for_about(changeset) do
    case {get_field(changeset, :about), get_field(changeset, :activity)} do
      {about, nil} when is_binary(about) and about != "" ->
        add_error(changeset, :activity, "say what you are doing with it")

      _otherwise ->
        changeset
    end
  end

  def moods, do: @moods
  def activities, do: @activities

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
