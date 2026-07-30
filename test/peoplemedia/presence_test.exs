defmodule Peoplemedia.PresenceTest do
  @moduledoc """
  Being here is a STATE, and everything here guards that.

  Every convenience presence has — silent expiry, no sweep job, two tabs being
  one person — falls out of there being exactly one row, and all of them break
  quietly if a second ever appears. That is the opposite of a round, which is an
  act and must accumulate; the split between the two is what these two files are.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{People, Presence, Repo}
  alias Peoplemedia.Presence.Presence, as: Row

  import Ecto.Query
  import Peoplemedia.Fixtures

  defp rows(person), do: Repo.all(from(pr in Row, where: pr.person_id == ^person.id))

  defp expire(person) do
    past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
    Repo.update_all(from(pr in Row, where: pr.person_id == ^person.id), set: [expires_at: past])
  end

  test "opening the app is the whole gesture" do
    me = person("OJO")

    refute Presence.here?(me.id)
    assert {:ok, _} = Presence.touch(me.id)
    assert Presence.here?(me.id)
  end

  # TWO TABS IS ONE PERSON BEING HERE, NOT TWO. Everything downstream — one query
  # for the whole list, no sweep, expiry that is just a comparison — rests on
  # there being exactly one row, so this is the load-bearing test.
  test "touching twice writes over, it does not accumulate" do
    me = person("OJO")

    {:ok, _} = Presence.touch(me.id)
    {:ok, _} = Presence.touch(me.id)

    assert length(rows(me)) == 1
  end

  test "presence that has run out is not presence" do
    me = person("OJO")
    {:ok, _} = Presence.touch(me.id)
    expire(me)

    refute Presence.here?(me.id)
    # The ROW is still there. Expiry is a comparison, not a delete — which is
    # what lets the next touch be an update rather than a resurrection.
    assert length(rows(me)) == 1
  end

  test "and coming back is the same row again" do
    me = person("OJO")
    {:ok, _} = Presence.touch(me.id)
    expire(me)
    {:ok, _} = Presence.touch(me.id)

    assert Presence.here?(me.id)
    assert length(rows(me)) == 1
  end

  test "leaving goes quiet without deleting" do
    me = person("OJO")
    {:ok, _} = Presence.touch(me.id)

    {:ok, _} = Presence.leave(me.id)

    refute Presence.here?(me.id)
    assert length(rows(me)) == 1
  end

  # THE FILTER IS IN THE CONTEXT, NOT IN THE CALLERS, and that is the point: there
  # is no read path to a hidden person because there is no other way in.
  test "a hidden person is not here even while their presence is good" do
    me = person("OJO")
    {:ok, _} = Presence.touch(me.id)
    {:ok, me} = People.set_around_hidden(me, true)

    refute Presence.here?(me.id)
    assert Presence.live_for([me.id]) == MapSet.new()
    assert Presence.hidden?(me)
  end

  test "one call answers for everybody, and only for those still here" do
    here = person("HERE")
    gone = person("GONE")
    never = person("NEVER")

    {:ok, _} = Presence.touch(here.id)
    {:ok, _} = Presence.touch(gone.id)
    expire(gone)

    assert Presence.live_for([here.id, gone.id, never.id]) == MapSet.new([here.id])
  end

  test "nobody asked about is nobody queried" do
    assert Presence.live_for([]) == MapSet.new()
  end

  # The surface says it is still here on a beat rather than on activity, so an
  # idle open tab does not fade out of a room it never left. The beat has to be
  # comfortably inside the window it renews, or it arrives after the thing it was
  # renewing has gone.
  test "an open surface renews well inside the window it is renewing" do
    assert Presence.beat_ms() < Presence.minutes() * 60 * 1000
  end
end
