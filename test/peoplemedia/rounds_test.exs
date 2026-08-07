defmodule Peoplemedia.RoundsTest do
  @moduledoc """
  Going round is an ACT, and everything here guards that one sentence.

  The thing it grew out of was a state — one row per person, written over — and
  every convenience of that model is exactly what a round must not have. A round
  is made, kept, and made again; the tests that matter most are the ones proving
  it never gets edited and never gets deleted.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{Relationships, Repo, Rounds}
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
      assert %{live: true, number: 1} = Rounds.live(me.id)
    end

    # PER CREATOR, INCREASING, and it never moves. Your third round stays your
    # third whatever happens to the ones before it — Law 4 means nothing before
    # it goes away, and a number that renumbered would make a word point at
    # something else.
    test "and each one is numbered after the last" do
      me = person("OJO")
      other = person("SARAH")

      {:ok, _} = Rounds.go(me.id)
      {:ok, _} = Rounds.go(me.id)
      {:ok, _} = Rounds.go(other.id)

      assert [%{number: 2}, %{number: 1}] = Rounds.history(me.id)
      assert [%{number: 1}] = Rounds.history(other.id)
    end

    # THE LOAD-BEARING TEST. A round is made, not edited — a person's page lists
    # what they have been up to, and a pair's page interleaves every round
    # between them. Neither is possible against a row that gets written over.
    test "going round twice keeps both" do
      me = person("OJO")

      {:ok, _} = Rounds.go(me.id)
      {:ok, _} = Rounds.go(me.id)

      assert length(rows(me)) == 2
      # The newest is the one that surfaces them; the older simply stops.
      assert %{number: 2} = Rounds.live(me.id)
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
          number: 1,
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
      {:ok, _} = Rounds.go(me.id)
      expire(me)

      assert Rounds.live(me.id) == nil
      assert length(rows(me)) == 1
      assert [%{live: false, number: 1}] = Rounds.history(me.id)
    end

    # IT DOES NOT COME BACK. Going round again is one tap and a new row, so there
    # is nothing to revive and no state to reconcile.
    test "an expired round is not revived by the creator returning" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id)
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
      {:ok, _} = Rounds.go(me.id)

      assert Rounds.stop(me.id) == 1
      assert Rounds.live(me.id) == nil
      assert [%{number: 1}] = Rounds.history(me.id)
    end
  end

  describe "reading the whole list at once" do
    test "one call answers for everybody still round" do
      up = person("UP")
      over = person("OVER")
      never = person("NEVER")

      {:ok, _} = Rounds.go(up.id)
      {:ok, _} = Rounds.go(over.id)
      expire(over)

      live = Rounds.live_for([up.id, over.id, never.id])

      assert Map.keys(live) == [up.id]
      assert live[up.id]
    end

    test "a hidden person is not round even while their round is good" do
      me = person("OJO")
      {:ok, _} = Rounds.go(me.id)
      {:ok, _} = Peoplemedia.People.set_around_hidden(me, true)

      assert Rounds.live(me.id) == nil
      assert Rounds.live_for([me.id]) == %{}
    end

    # THE LIST SORTS ON THIS AND EXPIRY DOES NOT TOUCH IT. Being overtaken is
    # something somebody else did; fading is not, so fading must not move you.
    # POSITION IS CONTENT. The order sorts on this, so a private round answering
    # here for a stranger would put its creator at the top of their list — which
    # says "something happened" as plainly as the words would have.
    test "and a private round does not order a stranger's list" do
      me = cast()
      {:ok, _} = Rounds.go(me.id, %{audience: "private"})

      assert Rounds.last_round_for([me.id], person("NOBODY").id) == %{}
      assert Map.has_key?(Rounds.last_round_for([me.id], me.id), me.id)
    end

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

  describe "who may see it" do
    # THE ONE THAT WAS MISSING, and it was invisible from the surface: a private
    # round rendered exactly like a public one, so it looked right while being
    # shown to strangers.
    test "a private round is not visible to a stranger" do
      me = cast()
      stranger = person("NOBODY")
      {:ok, _} = Rounds.go(me.id, %{audience: "private"})

      assert Rounds.live_for([me.id], stranger.id) == %{}
      assert Rounds.live_for([me.id], nil) == %{}, "a visitor least of all"
    end

    test "but it is visible to the people you hold" do
      me = cast()
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, _} = Rounds.go(me.id, %{audience: "private"})

      assert Rounds.live_for([me.id], them.id)[me.id]
    end

    # HOLDING SOMEBODY IS NOT BEING HELD BY THEM. The audience of a private round
    # is the creator's scopes, so it is their list that decides — not yours.
    test "and not to somebody who merely holds you back the other way" do
      me = cast()
      onlooker = person("ONLOOKER")
      {:ok, _} = Relationships.request_scope(onlooker.id, me.id, "OJO")
      {:ok, _} = Relationships.scope_back(me.id, onlooker.id, "THEM")
      {:ok, _} = Relationships.accept(onlooker.id, me.id)

      {:ok, _} = Rounds.go(onlooker.id, %{audience: "private"})

      # The onlooker holds me, so I am in THEIR audience.
      assert Rounds.live_for([onlooker.id], me.id)[onlooker.id]
      # A third party is in nobody's.
      assert Rounds.live_for([onlooker.id], person("THIRD").id) == %{}
    end

    test "a private round aimed at one person reaches only them" do
      me = cast()
      [{_a, them}, {_b, other} | _] = Relationships.held_by(me.id)
      {:ok, _} = Rounds.go(me.id, %{audience: "private", target_id: them.id})

      assert Rounds.live_for([me.id], them.id)[me.id]
      assert Rounds.live_for([me.id], other.id) == %{}
    end

    test "a public round reaches everybody, passport or not" do
      me = cast()
      {:ok, _} = Rounds.go(me.id, %{audience: "public"})

      assert Rounds.live_for([me.id], person("ANYONE").id)[me.id]
      assert Rounds.live_for([me.id], nil)[me.id]
    end

    test "and your own is always yours to see, whoever it is for" do
      me = cast()
      {:ok, _} = Rounds.go(me.id, %{audience: "private"})

      assert Rounds.live(me.id)
    end
  end

  describe "a person's history" do
    test "newest first, expired ones included" do
      me = person("OJO")

      {:ok, _} = Rounds.go(me.id)
      expire(me)
      {:ok, _} = Rounds.go(me.id)

      assert [%{number: 2}, %{number: 1}] = Rounds.history(me.id)
    end

    test "and somebody else's is not yours" do
      me = person("OJO")
      them = person("SARAH")
      {:ok, _} = Rounds.go(them.id)

      assert Rounds.history(me.id) == []
      assert [%{number: 1}] = Rounds.history(them.id)
    end
  end
end
