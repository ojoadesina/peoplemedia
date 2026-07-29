defmodule Peoplemedia.AroundTest do
  @moduledoc """
  Being around is a STATE, not an event.

  Most of what is here guards that one sentence, because every convenience the
  feature has — silent expiry, no sweep job, two tabs being one person — falls
  out of it, and all of them break quietly if a second row ever appears.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{Around, People, Repo}
  alias Peoplemedia.Around.Around, as: Row

  import Ecto.Query
  import Peoplemedia.Fixtures

  defp rows(person), do: Repo.all(from(a in Row, where: a.person_id == ^person.id))

  defp expire(person) do
    past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
    Repo.update_all(from(a in Row, where: a.person_id == ^person.id), set: [expires_at: past])
  end

  describe "the silent around" do
    test "opening the app is the whole gesture" do
      me = person("OJO")

      assert {:ok, _} = Around.touch(me.id)
      assert %{mood: nil, activity: nil, about: nil} = Around.of(me.id)
    end

    # TWO TABS IS ONE PERSON BEING HERE, NOT TWO. Everything downstream — one
    # query for the whole list, no sweep, expiry that is just a comparison —
    # rests on there being exactly one row, so this is the load-bearing test.
    test "touching twice writes over, it does not accumulate" do
      me = person("OJO")

      {:ok, _} = Around.touch(me.id)
      {:ok, _} = Around.touch(me.id)

      assert length(rows(me)) == 1
    end

    test "an around that has run out is not around" do
      me = person("OJO")
      {:ok, _} = Around.touch(me.id)
      expire(me)

      assert Around.of(me.id) == nil
      # The ROW is still there. Expiry is a comparison, not a delete — which is
      # what lets the next touch be an update rather than a resurrection.
      assert length(rows(me)) == 1
    end

    test "and coming back is the same row again" do
      me = person("OJO")
      {:ok, _} = Around.touch(me.id)
      expire(me)
      {:ok, _} = Around.touch(me.id)

      assert Around.of(me.id)
      assert length(rows(me)) == 1
    end

    test "somebody who never opened it is not around" do
      assert Around.of(person("OJO").id) == nil
    end
  end

  describe "the loud around" do
    test "a mood, a doing and the thing" do
      me = person("OJO")

      {:ok, _} =
        Around.speak(me.id, %{mood: "happy", activity: "watching", about: "the witchers"})

      assert %{mood: "happy", activity: "watching", about: "the witchers"} = Around.of(me.id)
    end

    # A MOOD WITH NO ACTIVITY IS A COMPLETE SENTENCE — "I am here and I am low".
    # Requiring both would make the quieter half of the feature unreachable.
    test "either half alone is enough" do
      a = person("A")
      b = person("B")

      {:ok, _} = Around.speak(a.id, %{mood: "sad"})
      {:ok, _} = Around.speak(b.id, %{activity: "reading"})

      assert %{mood: "sad", activity: nil} = Around.of(a.id)
      assert %{mood: nil, activity: "reading"} = Around.of(b.id)
    end

    test "going loud fills in the around you already have, it does not start another" do
      me = person("OJO")

      {:ok, _} = Around.touch(me.id)
      {:ok, _} = Around.speak(me.id, %{mood: "calm"})

      assert length(rows(me)) == 1
      assert %{mood: "calm"} = Around.of(me.id)
    end

    test "going loud says you are here as well" do
      me = person("OJO")
      {:ok, _} = Around.touch(me.id)
      expire(me)

      {:ok, _} = Around.speak(me.id, %{mood: "calm"})

      assert Around.of(me.id), "setting a mood and then vanishing loses the one thing they said"
    end

    test "a word outside either vocabulary is refused" do
      me = person("OJO")

      assert {:error, mood} = Around.speak(me.id, %{mood: "peckish"})
      assert "is invalid" in errors_on(mood).mood

      assert {:error, doing} = Around.speak(me.id, %{activity: "vibing"})
      assert "is invalid" in errors_on(doing).activity
    end

    # "The witchers" alone does not say whether you are watching it, reading it
    # or arguing about it.
    test "a thing with no kind of thing is not an answer" do
      me = person("OJO")

      assert {:error, changeset} = Around.speak(me.id, %{about: "the witchers"})
      assert errors_on(changeset).activity != []
    end

    test "an empty field is absent, not invalid" do
      me = person("OJO")

      assert {:ok, _} = Around.speak(me.id, %{mood: "", activity: "", about: ""})
      assert %{mood: nil, activity: nil, about: nil} = Around.of(me.id)
    end

    test "hushing goes quiet without deleting" do
      me = person("OJO")
      {:ok, _} = Around.speak(me.id, %{mood: "happy"})

      {:ok, _} = Around.hush(me.id)

      assert Around.of(me.id) == nil
      assert length(rows(me)) == 1
    end
  end

  describe "refusing to appear" do
    # THE FILTER IS IN THE CONTEXT, NOT IN THE CALLERS, and that is the point of
    # the test: there is no read path to a hidden person because there is no
    # other way in. A caller that could forget this would leak somebody who
    # asked not to be seen.
    test "a hidden person is not around even while their around is good" do
      me = person("OJO")
      {:ok, _} = Around.speak(me.id, %{mood: "happy"})
      {:ok, me} = People.set_around_hidden(me, true)

      assert Around.of(me.id) == nil
      assert Around.live_for([me.id]) == %{}
      assert Around.hidden?(me)
    end

    test "and comes back when they say so" do
      me = person("OJO")
      {:ok, _} = Around.speak(me.id, %{mood: "happy"})
      {:ok, me} = People.set_around_hidden(me, true)
      {:ok, me} = People.set_around_hidden(me, false)

      assert %{mood: "happy"} = Around.of(me.id)
    end
  end

  describe "reading the whole list at once" do
    test "one call answers for everybody, and only for those still here" do
      here = person("HERE")
      gone = person("GONE")
      never = person("NEVER")

      {:ok, _} = Around.speak(here.id, %{mood: "content"})
      {:ok, _} = Around.touch(gone.id)
      expire(gone)

      live = Around.live_for([here.id, gone.id, never.id])

      assert Map.keys(live) == [here.id]
      assert %{mood: "content"} = live[here.id]
    end

    test "nobody asked about is nobody queried" do
      assert Around.live_for([]) == %{}
    end
  end

  describe "the beat" do
    # The surface says it is still here on a beat rather than on activity, so an
    # idle open tab does not fade out of a room it never left. It has to be
    # comfortably inside the window it is renewing, or the renewal arrives after
    # the thing it was renewing has gone.
    test "an open surface renews well inside the window it is renewing" do
      assert Around.beat_ms() < Around.minutes() * 60 * 1000,
             "the beat must be shorter than the around it keeps alive"
    end
  end
end
