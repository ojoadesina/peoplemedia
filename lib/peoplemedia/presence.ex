defmodule Peoplemedia.Presence do
  @moduledoc """
  Who is here.

  AUTOMATIC, AND IT SAYS ONE THING. Opening the app is the whole gesture: no
  press, no announcement, and nothing to fill in. Mood, doing and words were all
  on this row once and have gone to `Rounds`, because being HERE is a state and
  going ROUND is an act — and a row holding both let neither be itself.

  ## IT IS NOT THE POINT, AND THAT IS THE POINT

  A roll of names with dots beside them is a museum: things to look at, nothing
  to join. Presence says people exist; a ROUND says somebody chose to be seen and
  what they chose to be seen doing, which is the only one of the two that gives
  you a reason to say anything. Presence is how you see people. Rounds are why.

  ## IT DIES QUIETLY

  `expires_at` in the past means not here, and that is the entire mechanism.
  Nothing sweeps, nothing broadcasts, and there is no moment at which the app
  tells anyone you have gone — you fade out of the surface the way you fade out
  of a room. Law 1: absence is silent.

  ## AND YOU CAN REFUSE IT ENTIRELY

  `around_hidden` on the person is checked HERE rather than by callers, so there
  is no read path that can forget it. Presence that is automatic and on by
  default has to have its way out in the same place as its way in.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.People.Person
  alias Peoplemedia.Presence.Presence, as: Row
  alias Peoplemedia.Repo

  # HOW LONG YOU LINGER AFTER THE LAST THING YOU DID.
  #
  # FIXED, NOT MEASURED, and the reason is not that an algorithm would be wrong.
  # A person has to be able to answer "why am I still showing?", and "we measured
  # how long you spent in the app" is not an answer that can go on a screen.
  @minutes 45

  # HOW OFTEN AN OPEN SURFACE SAYS IT IS STILL THERE.
  #
  # A WRITE PER KEYSTROKE IS NOT PRESENCE, IT IS TELEMETRY — so the surface does
  # not touch on activity at all. It touches on a beat, which covers the case
  # activity misses entirely: a tab left open and idle is somebody who is still
  # here, and a presence that expired under them would have them fade out of a
  # room they never left.
  #
  # The same beat re-reads the lists, because presence expires QUIETLY: nothing
  # is broadcast when somebody goes, so a screen that only ever redrew on a
  # notification would show people who left an hour ago.
  @beat_minutes 5

  @doc "Here. Called on connect and on the beat, and it says nothing else."
  def touch(person_id) do
    %Row{}
    |> Row.changeset(%{person_id: person_id, expires_at: horizon()})
    |> Repo.insert(
      # UPSERT, because the row is a state and states are written over. Two tabs
      # open is one person being here, not two.
      on_conflict: [set: [expires_at: horizon(), updated_at: naive_now()]],
      conflict_target: :person_id
    )
  end

  @doc """
  Gone now. Not a delete — the row stays, so the next `touch/1` is an update
  rather than a resurrection, and "have they ever been here" keeps an answer.
  """
  def leave(person_id) do
    case Repo.get_by(Row, person_id: person_id) do
      nil ->
        {:ok, nil}

      row ->
        row |> Row.changeset(%{person_id: person_id, expires_at: now()}) |> Repo.update()
    end
  end

  @doc "Whether this person is here."
  def here?(nil), do: false
  # MapSet.member?, NOT Map.has_key? — `live_for/1` returns a set, and a MapSet is
  # a struct, so asking a map question of it answers false for everybody forever.
  def here?(person_id), do: MapSet.member?(live_for([person_id]), person_id)

  @doc """
  Everyone still here, out of the given ids — a `MapSet` of person ids.

  ONE QUERY FOR THE WHOLE LIST, not one per row. The list is a country's worth of
  people and it is redrawn on every mount.

  A SET RATHER THAN A MAP, because there is nothing to carry. That is the whole
  difference between this and `Rounds.live_for/1`: presence has no contents, so
  the honest return is membership.
  """
  def live_for([]), do: MapSet.new()

  def live_for(person_ids) do
    at = now()

    Repo.all(
      from(pr in Row,
        join: p in Person,
        on: p.id == pr.person_id,
        where: pr.person_id in ^person_ids and pr.expires_at > ^at and p.around_hidden == false,
        select: pr.person_id
      )
    )
    |> MapSet.new()
  end

  @doc "Whether this person is appearing at all. The global way out."
  def hidden?(%Person{around_hidden: hidden}), do: hidden

  @doc "How long presence lasts past your last contact, in minutes."
  def minutes, do: @minutes

  @doc "How often an open surface says it is still there, in milliseconds."
  def beat_ms, do: @beat_minutes * 60 * 1000

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp naive_now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  defp horizon,
    do: DateTime.utc_now() |> DateTime.add(@minutes * 60, :second) |> DateTime.truncate(:second)
end
