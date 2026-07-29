defmodule PeoplemediaWeb.AroundTest do
  @moduledoc """
  ARE THEY HERE, AND IF THEY ARE, WHAT ARE THEY DOING?

  The surface half. What the boxes beside the band say, what the head of the list
  says now that two of those boxes moved up there, and the one act that fills any
  of it in.
  """
  use PeoplemediaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Peoplemedia.Fixtures

  alias Peoplemedia.{Around, People, Relationships}

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
    # THERE IS NO PRESS. Being here is what having the surface open MEANS, so
    # mounting is the whole gesture — anything else would be asking people to
    # announce that they had arrived somewhere they were already standing.
    test "makes you around, silently", %{conn: _conn} do
      other = passported("nobody", ~w(one two three), "1111")
      assert Around.of(other.id) == nil

      {:ok, _live, _html} = live(check_in(build_conn(), other), ~p"/")

      assert %{mood: nil, activity: nil} = Around.of(other.id)
    end

    test "a visitor is nobody, so nothing is written", %{conn: _conn} do
      {:ok, _live, _html} = live(build_conn(), ~p"/")
      # Nothing to assert an id against — the point is that it did not crash
      # reaching for one.
      assert true
    end
  end

  describe "the row says whether they are here" do
    test "present for somebody around, absent for somebody who is not", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ ~s(data-state="present")
      assert html =~ ~s(data-state="absent")
    end

    # `live` MEANS A FACE OR A VOICE ACTUALLY RUNNING — one thing somebody might
    # be doing inside an around, not what being around is. Most people are here
    # with the camera off, and reducing presence to streaming is the mistake this
    # whole feature exists to avoid.
    test "and never says live, which is not around's word", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")
      refute html =~ ~s(data-state="live")
    end

    test "somebody who goes quiet reads as absent", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, _} = Around.speak(them.id, %{mood: "happy"})

      {:ok, live, _} = live(conn, ~p"/")
      assert render(live) =~ ~s(data-state="present")

      {:ok, _} = Around.hush(them.id)
      send(live.pid, :stir)

      row =
        render(live)
        |> String.split(~s(class="scopes-item))
        |> Enum.find(&(&1 =~ them.name))

      assert row =~ ~s(data-state="absent")
    end
  end

  describe "the boxes beside the band" do
    test "hold what the settled person is doing and how they are", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "MUM")

      said = boxes(live)
      assert said =~ "WATCHING"
      assert said =~ "THE WITCHERS"
      assert said =~ "HAPPY"
      assert said =~ ~s(data-family="joy")
    end

    # MOST PEOPLE ARE AROUND SILENTLY — here, and saying nothing about it. The
    # slots stay so the letter box, which is anchored to the app's right edge,
    # does not slide sideways every time one of them passes under the band.
    test "and hold nothing, but keep their slot, for somebody silent", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "DAD")

      said = boxes(live)
      refute said =~ "JOYFUL"
      refute said =~ "WATCHING"
      assert said =~ "around-box", "an empty box keeps its slot or the letter box moves"
      refute said =~ ~s(data-family=")
    end

    test "nothing at all for somebody who is not here", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "COACH")

      said = boxes(live)
      refute said =~ "JOYFUL"
      assert said =~ "around-box"
    end
  end

  describe "the head of the list" do
    # A PLACE AND A POPULATION ARE FACTS ABOUT THE LIST — the same whichever name
    # has scrolled into the band — so they read at the head of it, and the rail
    # is left to the three things that genuinely answer the band.
    test "carries the two facts that are about the list, and the rail does not",
         %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")

      tags = live |> element(".list-tags") |> render()
      assert tags =~ "FINLAND"
      assert tags =~ "RELATIONSHIPS"

      refute boxes(live) =~ "FINLAND"
      refute boxes(live) =~ "RELATIONSHIPS"
    end

    test "and the count survives losing its size", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      tags = live |> element(".list-tags") |> render() |> String.replace(~r/<[^>]*>/, " ")

      assert tags =~ "#{held_count()}"
    end
  end

  describe "going loud" do
    test "the room asks three things and any one of them is an answer",
         %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      # THE ROOM IS THE LIST'S OWN SHAPE: a bar for the words, and the same
      # three boxes that answer the band on the page behind it.
      room = render(live)
      assert room =~ "AROUND"
      assert room =~ "DOING"
      assert room =~ "MOOD"

      # AND A BOX OPENS ONTO EVERYTHING IT COULD HOLD — the moods in their
      # families, coloured by the family rather than by the word.
      live |> element(~s(button[phx-click="pick_open"][phx-value-which="mood"])) |> render_click()
      open = render(live)
      assert open =~ "HEARTBROKEN"
      assert open =~ "SORROW"
      assert open =~ ~s(data-family="sorrow")

      live |> element(~s(button[phx-value-which="mood"][phx-value-word="calm"])) |> render_click()
      assert render(live) =~ "CALM"

      # THE WAY OUT OF AN OPEN BOX. `foot/1` renders this button whenever it is
      # asked for one, and the room it was written for is a different LiveView
      # with its own handler — a shared component's events are not shared, and
      # without a clause here pressing it took the process down.
      live
      |> element(~s(button[phx-click="pick_open"][phx-value-which="activity"]))
      |> render_click()

      assert render(live) =~ "TRAVELLING"
      live |> element(~s(button[phx-click="back"])) |> render_click()
      refute render(live) =~ "TRAVELLING"

      # A MOOD ON ITS OWN IS A COMPLETE THING TO SAY. No letter, and nothing has
      # gone wrong.
      render_submit(live, :write_letter, %{"mood" => "calm", "body" => ""})

      assert %{mood: "calm"} = Around.of(me.id)
      assert Peoplemedia.Letters.broadcasts_by(me.id) == []
      assert_push_event(live, "toast", %{words: "AROUND — CALM"})
    end

    test "all three at once", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      render_submit(live, :write_letter, %{
        "mood" => "happy",
        "activity" => "watching",
        "about" => "the witchers",
        "body" => "i cannot believe this season"
      })

      assert %{mood: "happy", activity: "watching", about: "the witchers"} = Around.of(me.id)
      assert [%{body: "i cannot believe this season"}] = Peoplemedia.Letters.broadcasts_by(me.id)
      assert_push_event(live, "toast", %{words: "SENT TO THE WORLD"})
    end

    # HOW YOU ARE IS ABOUT YOU, NOT ABOUT THE LETTER. Writing to one person while
    # happy does not make you privately happy.
    test "a mood set while writing to somebody is still your own", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)

      {:ok, live, _} = live(conn, ~p"/")
      settle(live, them.name)
      live |> element(".focus-box") |> render_click()
      live |> element("#act") |> render_click()

      render_submit(live, :write_letter, %{"mood" => "restless", "body" => "are you well"})

      assert %{mood: "restless"} = Around.of(me.id)
      assert [%{body: "are you well"} | _] = Peoplemedia.Letters.thread(me.id, them.id)
    end

    test "an empty room is refused and says so", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      assert render_submit(live, :write_letter, %{"body" => "   "}) =~ "SAY SOMETHING"
      assert Around.of(me.id).mood == nil
    end

    test "a mood outside the vocabulary writes nothing at all", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      render_submit(live, :write_letter, %{"mood" => "peckish", "body" => "hello world"})

      # THE AROUND IS SET FIRST ON PURPOSE, so a refusal lands before a letter is
      # written — nobody ends up having said something whose state they cannot see.
      assert Peoplemedia.Letters.broadcasts_by(me.id) == []
    end
  end

  describe "the room's own wiring" do
    # HEEx DROPS AN ATTRIBUTE WHOSE VALUE IS nil, so an unanswered mood rendered
    # as an input with no `value` at all — and the stylesheet's test for "nothing
    # chosen yet" is `[value=""]`, which an absent attribute does not match. The
    # check sat enabled over an empty room, offering an act that would then be
    # refused.
    test "an unanswered choice still renders an empty value", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      room = render(live)
      assert room =~ ~s(name="mood" value=""), "an absent value cannot be tested for"
      assert room =~ ~s(name="activity" value="")
    end

    # The choices stopped being radios when a box began opening onto its own
    # grid; the rule that greys the check had to stop asking about `:checked`.
    test "the check is offered on any one of the three" do
      css = File.read!("assets/css/app.css")
      refute css =~ "[name=\"mood\"]:checked", "there are no radios in this room any more"
      assert css =~ "[name=\"mood\"]:not([value=\"\"])"
    end
  end

  describe "refusing to appear" do
    test "hidden removes you from the boxes while leaving you in the list",
         %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, _} = Around.speak(them.id, %{mood: "happy", activity: "reading"})
      {:ok, _} = People.set_around_hidden(them, true)

      {:ok, live, html} = live(conn, ~p"/")
      assert html =~ them.name

      settle(live, them.name)
      said = boxes(live)
      refute said =~ "JOYFUL"
      refute said =~ "READING"
    end

    test "the passport room is where you turn it off", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")

      assert render(live) =~ "BEING AROUND"
      assert render(live) =~ "SHOWING WHEN YOU ARE HERE"
    end
  end
end
