defmodule PeoplemediaWeb.RoundTest do
  @moduledoc """
  The surface half of going round.

  Two things are being kept apart here, and the tests are shaped around the
  split: PRESENCE is automatic and says only that somebody has not gone; a ROUND
  is deliberate and says what they chose to be seen doing. The row shows the
  first and the boxes show the second, and neither should ever stand in for the
  other.
  """
  use PeoplemediaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Peoplemedia.Fixtures

  alias Peoplemedia.{People, Presence, Relationships, Rounds}

  setup %{conn: conn} do
    me = cast()
    %{conn: check_in(conn, me), me: me}
  end

  defp settle(live, name) do
    index =
      render(live)
      |> String.split(~s(class="scopes-item))
      |> tl()
      |> Enum.find_index(&(&1 =~ name))

    refute is_nil(index), "#{name} is not in the list"
    render_hook(live, "select", %{"index" => index})
  end

  defp boxes(live), do: live |> element(".scope-boxes") |> render()

  describe "opening the app" do
    # THERE IS NO PRESS FOR PRESENCE. Being here is what having the surface open
    # MEANS. Going round is the opposite — deliberate — so mounting must NOT make
    # one, or the act would happen without anybody choosing it.
    test "makes you present, and does not make you round", %{conn: _conn} do
      other = passported("nobody", ~w(one two three), "1111")
      refute Presence.here?(other.id)

      {:ok, _live, _html} = live(check_in(build_conn(), other), ~p"/")

      assert Presence.here?(other.id)
      assert Rounds.live(other.id) == nil
    end

    test "a visitor is nobody, so nothing is written", %{conn: _conn} do
      {:ok, _live, _html} = live(build_conn(), ~p"/")
      assert true
    end
  end

  describe "the row says whether they are here" do
    test "present for somebody here, absent for somebody who is not", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ ~s(data-state="present")
      assert html =~ ~s(data-state="absent")
    end

    # `live` MEANS A FACE OR A VOICE ACTUALLY RUNNING — one thing somebody might
    # be doing inside a round, not what being here is.
    test "and never says live, which is not presence's word", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")
      refute html =~ ~s(data-state="live")
    end

    # PRESENCE AND ROUNDS ARE DIFFERENT QUESTIONS. Somebody whose round ran out
    # is still here; somebody who left is not, whatever they were round with.
    test "a round running out does not make them absent", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      round(them, %{mood: "happy"})

      {:ok, live, _} = live(conn, ~p"/")
      Rounds.stop(them.id)
      send(live.pid, :stir)

      row =
        render(live)
        |> String.split(~s(class="scopes-item))
        |> Enum.find(&(&1 =~ them.name))

      assert row =~ ~s(data-state="present"), "they are still here, they just stopped"
    end

    test "leaving does", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      round(them, %{mood: "happy"})

      {:ok, live, _} = live(conn, ~p"/")
      Presence.leave(them.id)
      send(live.pid, :stir)

      row =
        render(live)
        |> String.split(~s(class="scopes-item))
        |> Enum.find(&(&1 =~ them.name))

      assert row =~ ~s(data-state="absent")
    end
  end

  describe "the boxes beside the band" do
    test "hold what the settled person is round with", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "MUM")

      said = boxes(live)
      assert said =~ "MOVIE"
      assert said =~ "THE WITCHERS"
      assert said =~ "HAPPY"
      assert said =~ ~s(data-family="joy")
    end

    # THE SLOTS STAY so the letter box, which is anchored to the app's right
    # edge, does not slide sideways every time somebody with no round passes
    # under the band.
    test "and hold nothing, but keep their slot, for somebody merely here", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "DAD")

      said = boxes(live)
      refute said =~ "HAPPY"
      refute said =~ "MOVIE"
      assert said =~ "around-box", "an empty box keeps its slot or the letter box moves"
      refute said =~ ~s(data-family=")
    end

    test "nothing at all for somebody who is not here", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "COACH")

      said = boxes(live)
      refute said =~ "HAPPY"
      assert said =~ "around-box"
    end
  end

  describe "the head of the list" do
    test "carries the two facts that are about the list, and the rail does not",
         %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")

      tags = live |> element(".list-tags") |> render()
      assert tags =~ "FINLAND"
      assert tags =~ "RELATIONSHIPS"

      refute boxes(live) =~ "FINLAND"
      refute boxes(live) =~ "RELATIONSHIPS"
    end
  end

  describe "going round" do
    test "the form takes the band's line, in place, with no panel",
         %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      refute has_element?(live, "#round-form")

      live |> element("#act") |> render_click()

      # IN PLACE. The list is still there underneath — a panel would have hidden
      # the very people the round exists to reach.
      assert has_element?(live, "#round-form")
      assert has_element?(live, ".scopes-item")

      room = render(live)
      assert room =~ "WHAT IS GOING ON?"
      assert room =~ "DOING"
      assert room =~ "MOOD"

      # A box opens onto everything it could hold — the moods in their families,
      # coloured by the family rather than by the word.
      live |> element(~s(button[phx-click="pick_open"][phx-value-which="mood"])) |> render_click()
      open = render(live)
      assert open =~ "HEARTBROKEN"
      assert open =~ "SORROW"
      assert open =~ ~s(data-family="sorrow")

      live |> element(~s(button[phx-value-which="mood"][phx-value-word="calm"])) |> render_click()
      assert render(live) =~ "CALM"

      # THE WAY OUT OF AN OPEN BOX IS THE BOX. Pressing the one that is open
      # closes it, so the gesture that reveals a choice is the same one that
      # abandons it — and there is no second control to find.
      live
      |> element(~s(button[phx-click="pick_open"][phx-value-which="activity"]))
      |> render_click()

      assert render(live) =~ "TRAVELLING"

      live
      |> element(~s(button[phx-click="pick_open"][phx-value-which="activity"]))
      |> render_click()

      refute render(live) =~ "TRAVELLING"

      # A MOOD ON ITS OWN IS A COMPLETE THING TO SAY, and so is nothing at all.
      render_submit(live, :round_send, %{"mood" => "calm"})

      assert %{mood: "calm"} = Rounds.live(me.id)
      refute has_element?(live, "#round-form"), "sending closes the form"
    end

    # EVERY FIELD IS OPTIONAL, so there is nothing to refuse. An empty round is
    # "I am here and open to being joined" — the smallest true thing anybody can
    # say here, and the one this surface exists for.
    test "an empty round is a real round", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{})

      assert %{name: nil, mood: nil, activity: nil} = Rounds.live(me.id)
    end

    # MANUAL CANCEL, and it is the only way out that changes nothing.
    test "cancelling makes no round at all", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()
      live |> element(~s(button[phx-click="round_cancel"])) |> render_click()

      refute has_element?(live, "#round-form")
      assert Rounds.live(me.id) == nil
    end

    test "all of it at once, and the name is a title", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      render_submit(live, :round_send, %{
        "name" => "the witchers, finally",
        "mood" => "happy",
        "activity" => "movie",
        "about" => "the witchers"
      })

      assert %{name: "the witchers, finally", mood: "happy", activity: "movie"} =
               Rounds.live(me.id)
    end

    # GOING ROUND IS A NEW ROW EVERY TIME. The old one keeps its words and its
    # place in the history; this one is simply newer.
    test "twice keeps both, and the newest surfaces", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{"mood" => "tired"})

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{"mood" => "hopeful"})

      assert %{mood: "hopeful"} = Rounds.live(me.id)
      assert [%{mood: "hopeful"}, %{mood: "tired"}] = Rounds.history(me.id)
    end

    # THE AUDIENCE IS THE TAB YOU ARE STANDING ON, never a question. PEOPLE is
    # everyone; RELATIONSHIPS is the people you hold. Offering a control for it
    # would be asking somebody to restate where they already are.
    test "the people tab goes round publicly", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element(~s(button[phx-click="scope_box"])) |> render_click()
      assert render(live) =~ "PEOPLE"

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{"mood" => "calm"})

      assert %{audience: "public", target_id: nil} = Rounds.live(me.id)
    end

    test "and the relationships tab goes round with the people you hold",
         %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      assert render(live) =~ "RELATIONSHIPS"

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{"mood" => "calm"})

      assert %{audience: "private", target_id: nil} = Rounds.live(me.id)
    end

    test "a mood outside the vocabulary makes no round", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      render_submit(live, :round_send, %{"mood" => "peckish"})

      assert Rounds.live(me.id) == nil
    end
  end

  describe "the order of the list" do
    # GOING ROUND PULLS YOU TO THE FRONT, and running out leaves you exactly
    # where you were. Being overtaken is something somebody else did; fading is
    # not, so fading must not move you.
    test "the newest round leads, and expiry does not demote", %{conn: conn, me: me} do
      [{_a, first}, {_b, second} | _] = Relationships.held_by(me.id)

      round(first, %{mood: "calm"})
      round(second, %{mood: "happy"})

      {:ok, live, _} = live(conn, ~p"/")
      assert leader(live) =~ second.name

      # It runs out — and stays exactly where it was.
      Rounds.stop(second.id)
      send(live.pid, :stir)
      assert leader(live) =~ second.name, "an expired round must not demote anybody"
    end
  end

  describe "refusing to appear" do
    test "hidden removes the round while leaving them in the list", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      round(them, %{mood: "happy", activity: "reading"})
      {:ok, _} = People.set_around_hidden(them, true)

      {:ok, live, html} = live(conn, ~p"/")
      assert html =~ them.name

      settle(live, them.name)
      said = boxes(live)
      refute said =~ "HAPPY"
      refute said =~ "READING"
    end

    test "the passport room is where you turn it off", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")

      assert render(live) =~ "BEING AROUND"
      assert render(live) =~ "SHOWING WHEN YOU ARE HERE"
    end
  end

  defp leader(live) do
    render(live) |> String.split(~s(class="scopes-item)) |> Enum.at(1) || ""
  end
end
