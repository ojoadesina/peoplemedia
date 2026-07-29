defmodule Peoplemedia.Around do
  @moduledoc """
  Who is here, and what they are doing.

  THE APP'S LINE IS "SO YOU DON'T DO LIFE ALONE", and until this existed nothing
  on the surface said anybody was here at all — `Directory` handed every row the
  word "present" and a comment admitting it was a placeholder.

  IT IS NOT A PRESENCE LIGHT. A roll of names with dots beside them is a museum:
  things to look at, nothing to join. An around answers two questions at once —
  are they here, and if they are, what are they doing — because the second is the
  only one that gives you a reason to say anything.

  ## SILENT AND LOUD

  SILENT is automatic. Opening the app is the whole gesture: `touch/1` on
  connect, no press, no announcement. Mood and activity are nil, which is a
  complete around and the commonest one.

  LOUD is one press, and it adds the mood, the doing and the specific thing. It
  is the same row — going loud does not start a second around, it fills in the
  one you already have.

  ## IT DIES QUIETLY

  `expires_at` in the past means not around, and that is the entire mechanism.
  Nothing sweeps, nothing broadcasts, and there is no moment at which the app
  tells anyone you have gone — you fade out of the surface the way you fade out
  of a room. See the migration for why one row per person is what makes this
  free.

  ## AND YOU CAN REFUSE IT ENTIRELY

  `around_hidden` on the person is checked HERE rather than by callers, so there
  is no read path that can forget it. Presence that is automatic and on by
  default has to have its way out in the same place as its way in.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.Around.Around, as: Row
  alias Peoplemedia.People.Person
  alias Peoplemedia.Repo

  # HOW LONG YOU LINGER AFTER THE LAST THING YOU DID.
  #
  # FIXED, NOT MEASURED, and the reason is not that an algorithm would be wrong.
  # A person has to be able to answer "why am I still showing?", and "we measured
  # how long you spent in the app" is not an answer that can go on a screen. A
  # number everyone can be told is worth more than a number that fits better.
  @minutes 45

  # HOW OFTEN AN OPEN SURFACE SAYS IT IS STILL THERE.
  #
  # A WRITE PER KEYSTROKE IS NOT PRESENCE, IT IS TELEMETRY — so the surface does
  # not touch on activity at all. It touches on a beat, which covers the case
  # activity misses entirely: a tab left open and idle is somebody who is still
  # here, and an around that expired under them would have them fade out of a
  # room they never left.
  #
  # The same beat re-reads the lists, because arounds expire QUIETLY: nothing is
  # broadcast when somebody goes, so a screen that only ever redrew on a
  # notification would show people who left an hour ago.
  @beat_minutes 5

  @doc """
  Here. The silent around — called on connect and as somebody goes on using the
  app, and it says nothing except that they have not gone.
  """
  def touch(person_id) do
    %Row{}
    |> Row.touch_changeset(%{person_id: person_id, expires_at: horizon()})
    |> Repo.insert(
      # UPSERT, because the row is a state and states are written over. Two tabs
      # open is one person being here, not two.
      on_conflict: [set: [expires_at: horizon(), updated_at: now()]],
      conflict_target: :person_id
    )
  end

  @doc """
  Here, and this is what I am doing. The loud around — the same row, filled in.

  IT TOUCHES TOO, so going loud is also saying you are here; a person who set a
  mood and then vanished from the list a minute later would be the app losing the
  one thing they took the trouble to tell it.
  """
  def speak(person_id, attrs) do
    attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), blank_to_nil(v)} end)
      |> Map.merge(%{"person_id" => person_id, "expires_at" => horizon()})

    case of_any_age(person_id) do
      nil -> %Row{}
      row -> row
    end
    |> Row.speak_changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Go quiet now. Not a delete — the row stays, so the next `touch/1` is an update
  rather than a resurrection, and "have they ever been here" keeps an answer.
  """
  def hush(person_id) do
    case of_any_age(person_id) do
      nil ->
        {:ok, nil}

      row ->
        row
        |> Row.touch_changeset(%{person_id: person_id, expires_at: now()})
        |> Repo.update()
    end
  end

  @doc "This person's around, or nil if they are not here."
  def of(nil), do: nil

  def of(person_id) do
    person_id |> List.wrap() |> live_for() |> Map.get(person_id)
  end

  @doc """
  Everyone still here, out of the given ids — `%{person_id => around}`.

  ONE QUERY FOR THE WHOLE LIST, not one per row. The list is a country's worth of
  people and it is redrawn on every mount; `Directory.census/1` counts headcounts
  the same way and for the same reason.

  HIDING IS APPLIED HERE. It is a join rather than a caller's filter precisely so
  that a caller cannot forget it — there is no path from a hidden person to a
  surface, because there is no other way in.
  """
  def live_for([]), do: %{}

  def live_for(person_ids) do
    at = now()

    Repo.all(
      from(a in Row,
        join: p in Person,
        on: p.id == a.person_id,
        where: a.person_id in ^person_ids and a.expires_at > ^at and p.around_hidden == false,
        select: a
      )
    )
    |> Map.new(&{&1.person_id, read(&1)})
  end

  @doc "Whether this person is appearing at all. The global way out."
  def hidden?(%Person{around_hidden: hidden}), do: hidden

  @doc "How long an around lasts past your last contact, in minutes."
  def minutes, do: @minutes

  @doc "How often an open surface says it is still there, in milliseconds."
  def beat_ms, do: @beat_minutes * 60 * 1000

  def moods, do: Row.moods()
  def activities, do: Row.activities()

  @doc "The moods in their families, warm to cold — see `Around.Around`."
  def mood_families, do: Row.mood_families()

  @doc "Which family a mood belongs to. The colour hangs off this, not off the mood."
  def family_of(mood), do: Row.family_of(mood)

  # WHAT A SURFACE IS HANDED. The row's own keys, minus the bookkeeping — the
  # same shape `Letters.read_from/2` establishes, so nothing above has to know
  # this is an Ecto struct.
  defp read(%Row{} = a) do
    %{
      mood: a.mood,
      # THE FAMILY COMES WITH THE MOOD, because everything that draws one needs
      # the colour and nothing that draws one should have to look it up. It is
      # derived rather than stored: a mood's family is a fact about the
      # vocabulary, and a column would let a row disagree with it.
      family: Row.family_of(a.mood),
      activity: a.activity,
      about: a.about,
      expires_at: a.expires_at
    }
  end

  # ANY AGE, because going loud must be able to reach an around that lapsed while
  # you were away — otherwise `speak/2` would insert a second row and the unique
  # index would refuse it.
  defp of_any_age(person_id), do: Repo.get_by(Row, person_id: person_id)

  # A FIELD SOMEBODY CLEARED IS A FIELD WITH NOTHING IN IT, and "" is not a mood.
  # The form sends empty strings for untouched radios and the closed-set
  # validation would call them invalid rather than absent.
  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp horizon,
    do: DateTime.utc_now() |> DateTime.add(@minutes * 60, :second) |> DateTime.truncate(:second)
end
