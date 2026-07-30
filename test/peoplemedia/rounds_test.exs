defmodule Peoplemedia.RoundsTest do
  @moduledoc """
  Going round is an ACT, and everything here guards that one sentence.

  The thing it grew out of was a state — one row per person, written over — and
  every convenience of that model is exactly what a round must not have. A round
  is made, kept, and made again; the tests that matter most are the ones proving
  it never gets edited and never gets deleted.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{Repo, Rounds}
  alias Peoplemedia.Rounds.Round

  import Ecto.Query
  import Peoplemedia.Fixtures

  defp rows(person), do: Repo.all(from(r in Round, where: r.person_id == ^person.id))

  defp expire(person) do
    past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
    Repo.update_all(from(r in Round, where: r.person_id == ^person.id), set: [expires_at: past])
  end

  describe "going round" do
    # A ROUND WITH NOTHING ON IT is somebody saying "I am here and open to being
    # joined", which is the smallest true thing this app exists to let anybody
    # say. Refusing it would make the quietest version of the act unreachable.
    test "works with nothing on it at all" do
      me = person("OJO")

      assert {:ok, _} = Rounds.go(me.id)
      assert %{name: nil, mood: nil, activity: nil, live: true} = Rounds.live(me.id)
    end

    test "and with all of it" do
      me = person("OJO")

      {:ok, _} =
        Rounds.go(me.id, %{
          name: "the witchers, finally",
          mood: "happy",
          activity: "movie",
          about: "the witchers"
        })

      assert %{name: "the witchers, finally", mood: "happy", family: "joy"} = Rounds.live(me.id)
    end

    # THE LOAD-BEARING TEST. A round is made, not edited — a person's page lists
    # what they have been up to, and a pair's page interleaves every round
    # between them. Neither is possible against a row that gets written over.
    test "going round twice keeps both" do
      me = person("OJO")

      {:ok, _} = Rounds.go(me.id, %{name: "first"})
      {:ok, _} = Rounds.go(me.id, %{name: "second"})

      assert length(rows(me)) == 2
      # The newest is the one that surfaces them; the older simply stops.
      assert %{name: "second"} = Rounds.live(me.id)
    end

    test "a word outside either vocabulary is refused" do
      me = person("OJO")

      assert {:error, mood} = Rounds.go(me.id, %{mood: "peckish"})
      assert "is invalid" in errors_on(mood).mood

      assert {:error, doing} = Rounds.go(me.id, %{activity: "vibing"})
      assert "is invalid" in errors_on(doing).activity
    end

    test "a thing with no kind of thing is not an answer" do
      me = person("OJO")

      assert {:error, changeset} = Rounds.go(me.id, %{about: "the witchers"})
      assert errors_on(changeset).activity != []
    end

    test "an empty field is absent, not invalid" do
      me = person("OJO")

      assert {:ok, _} = Rounds.go(me.id, %{name: "", mood: "", activity: "", about: ""})
      assert %{name: nil, mood: nil, activity: nil} = Rounds.live(me.id)
    end

    test "a name longer than a title is refused" do
      me = person("OJO")
      long = String.duplicate("a", Rounds.name_limit() + 1)

      assert {:error, changeset} = Rounds.go(me.id, %{name: long})
      assert errors_on(changeset).name != []
    end
  end

  describe "who it is for" do
    test "public by default, and public means no target" do
      me = person("OJO")

      {:ok, _} = Rounds.go(me.id)
      assert %{audience: "public", target_id: nil} = Rounds.live(me.id)
    end

    test "private to one person carries them" do
      me = person("OJO")
      them = person("SARAH")

      {:ok, _} = Rounds.go(me.id, %{audience: "private", target_id: them.id})
      assert %{audience: "private", target_id: target} = Rounds.live(me.id)
      assert target == them.id
    end

    # AIMING A PUBLIC ROUND IS NOT A STRICTER PUBLIC ROUND, it is two different
    # answers to one question.
    test "a public round cannot be aimed at anybody" do
      me = person("OJO")
      them = person("SARAH")

      assert {:error, changeset} = Rounds.go(me.id, %{audience: "public", target_id: them.id})
      assert errors_on(changeset).target_id != []
    end

    test "and the database says so too" do
      me = person("OJO")
      them = person("SARAH")

      at = DateTime.utc_now() |> DateTime.add(600, :second) |> DateTime.truncate(:second)

      assert_raise Ecto.ConstraintError, ~r/public_rounds_have_no_target/, fn ->
        Repo.insert(%Round{
          person_id: me.id,
          target_id: them.id,
          audience: "public",
          expires_at: at
        })
      end
    end
  end

  describe "expiry" do
    # LAW 4: expiry is about VISIBILITY, never deletion. The row keeps its name,
    # its mood and its age — it simply stops surfacing the person.
    test "stops it surfacing and deletes nothing" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id, %{name: "still here somewhere"})
      expire(me)

      assert Rounds.live(me.id) == nil
      assert length(rows(me)) == 1
      assert [%{name: "still here somewhere", live: false}] = Rounds.history(me.id)
    end

    # IT DOES NOT COME BACK. Going round again is one tap and a new row, so there
    # is nothing to revive and no state to reconcile.
    test "an expired round is not revived by the creator returning" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id, %{name: "the old one"})
      expire(me)

      assert Rounds.keep(me.id) == 0
      assert Rounds.live(me.id) == nil
    end

    test "but a live one is kept up while its creator is" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id)
      before = Rounds.live(me.id).expires_at

      Repo.update_all(from(r in Round, where: r.person_id == ^me.id),
        set: [expires_at: DateTime.add(before, -600, :second)]
      )

      assert Rounds.keep(me.id) == 1
      assert DateTime.compare(Rounds.live(me.id).expires_at, before) != :lt
    end

    test "stopping is not deleting either" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id, %{name: "done for now"})

      assert Rounds.stop(me.id) == 1
      assert Rounds.live(me.id) == nil
      assert [%{name: "done for now"}] = Rounds.history(me.id)
    end
  end

  describe "reading the whole list at once" do
    test "one call answers for everybody still round" do
      up = person("UP")
      over = person("OVER")
      never = person("NEVER")

      {:ok, _} = Rounds.go(up.id, %{mood: "content"})
      {:ok, _} = Rounds.go(over.id)
      expire(over)

      live = Rounds.live_for([up.id, over.id, never.id])

      assert Map.keys(live) == [up.id]
      assert %{mood: "content"} = live[up.id]
    end

    test "a hidden person is not round even while their round is good" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id, %{mood: "happy"})
      {:ok, _} = Peoplemedia.People.set_around_hidden(me, true)

      assert Rounds.live(me.id) == nil
      assert Rounds.live_for([me.id]) == %{}
    end

    # THE LIST SORTS ON THIS AND EXPIRY DOES NOT TOUCH IT. Being overtaken is
    # something somebody else did; fading is not, so fading must not move you.
    test "when they last went round outlives the round" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id)
      expire(me)

      assert Map.has_key?(Rounds.last_round_for([me.id]), me.id)
    end

    test "nobody asked about is nobody queried" do
      assert Rounds.live_for([]) == %{}
      assert Rounds.last_round_for([]) == %{}
    end
  end

  describe "a person's history" do
    test "newest first, expired ones included" do
      me = person("OJO")

      {:ok, _} = Rounds.go(me.id, %{name: "older"})
      expire(me)
      {:ok, _} = Rounds.go(me.id, %{name: "newer"})

      assert [%{name: "newer"}, %{name: "older"}] = Rounds.history(me.id)
    end

    test "and somebody else's is not yours" do
      me = person("OJO")
      them = person("SARAH")
      {:ok, _} = Rounds.go(them.id, %{name: "theirs"})

      assert Rounds.history(me.id) == []
      assert [%{name: "theirs"}] = Rounds.history(them.id)
    end
  end
end
