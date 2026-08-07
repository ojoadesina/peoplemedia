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

  # THE ROW SHOWS ONE WORD FOR A PERSON — the label you gave them. Searching by
  # their own name stopped finding anybody the day the second name came off.
  defp settle(live, name) do
    index =
      render(live)
      |> String.split(~s(class="scopes-item))
      |> tl()
      |> Enum.find_index(&(&1 =~ name))

    refute is_nil(index), "#{name} is not in the list"
    render_hook(live, "select", %{"index" => index})
  end

  defp item_for(live, name) do
    render(live)
    |> String.split(~s(class="scopes-item))
    |> tl()
    |> Enum.find(&(&1 =~ name))
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
    # TWO BOXES, NOT THREE, and the doing is not one of them. A sentence set in a
    # ten-rem box beside the band is a sentence you have to work to read; it is
    # carried on the person's PAGE instead, beside LETTERS, at a size that suits
    # it. What is left on the rail is what neither a line nor a page-heading does
    # well: a colour, and a frame.
    test "hold what a row cannot: a colour and a frame", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "MUM")

      # THE PLATE HOLDS BOTH, side by side: what they are up to, and how they
      # are. They were split across a row and a box on the rail, which put one
      # fact where you were reading and the other where you were not.
      item = item_for(live, "MUM")
      assert item =~ "HAPPY"
      assert item =~ ~s(data-family="joy")
      assert item =~ "THE WITCHERS, FINALLY"
    end

    # AND THE DOING IS ON NEITHER — NOT THE ROW, NOT THE RAIL.
    #
    # It spent a while on the ROW, on the argument that boxes answer one person
    # at a time and nobody should have to settle somebody to learn anything.
    # That argument is true and it lost anyway: a sentence under every name is a
    # FEED however fresh the sentence is, and this list is people-first or it is
    # nothing. The row keeps two GLYPHS, which are marks rather than words.
    #
    # SO IT IS ONE STEP FURTHER IN THAN IT WAS. Not settled — OPENED. The panel
    # carries it beside LETTERS and always has, which is also the only place your
    # own round is visible to you, since you have no row in your own list.
    test "and the doing is on their page, not on the row or the rail", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/")

      rows = html |> String.split(~s(class="scopes-item)) |> tl() |> Enum.join()
      assert rows =~ "THE WITCHERS, FINALLY"

      # AND ON THEIR PAGE TOO, with the mood it was made in — the panel takes the
      # band away, so without it walking into somebody loses the one thing the
      # column had just told you about them.
      settle(live, "MUM")
      assert render_click(live, "toggle_open") =~ "THE WITCHERS, FINALLY"
    end

    # THEY SIT ON A TRACK, AND THE TRACK IS WHAT MAKES THEM FIT ANYWHERE. Below
    # about 66rem the rail cannot hold the band and both boxes, and the answer
    # used to be a second layout that stacked them ABOVE the band — a row of grey
    # rectangles over the top of the list, answering a band they were no longer
    # beside. Now the cluster overflows instead of moving: `.boxes-lead` holds the
    # band's column and grows into whatever rail is spare, so a wide screen has
    # nothing to scroll and a phone shows the first box at its edge.
    #
    # THE NESTING IS THE LOAD-BEARING PART, which is why it is asserted rather
    # than left to the stylesheet. Two rules — the fade when a panel opens, and
    # the one that clears the rail for an expanded box — were written as DIRECT
    # children of the cluster, and both broke silently when the run went in
    # between: the second hid the run itself, and a box opening inside a hidden
    # parent measured zero and drew nothing.
    test "on a track, with the band's column held open in front of them", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "MUM")

      said = boxes(live)
      assert said =~ "boxes-lead", "without the lead the boxes sit on top of the band"
      assert said =~ "boxes-run"

      # The lead comes first, and the person frame is inside the run behind it.
      [_before, after_lead] = String.split(said, "boxes-lead", parts: 2)
      assert after_lead =~ "boxes-run"
      [_outside, inside_run] = String.split(said, "boxes-run", parts: 2)
      assert inside_run =~ "letterbox"
    end

    # THE SLOTS STAY so the letter box, which is anchored to the app's right
    # edge, does not slide sideways every time somebody with no round passes
    # under the band.
    test "and hold nothing, but keep their slot, for somebody merely here", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "DAD")

      # AN EMPTY PLATE HOLDS ITS WASH AND SAYS NOTHING, which is what every empty
      # thing on this surface does — and it is still drawn, because the band
      # settles on position and an item that shrank when nothing was happening
      # would move every item under it.
      item = item_for(live, "DAD")
      refute item =~ "HAPPY"
      refute item =~ "THE WITCHERS"
      assert item =~ "frame-plate"
      refute item =~ ~s(data-family=")
    end

    test "nothing at all for somebody who is not here", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "COACH")

      item = item_for(live, "COACH")
      refute item =~ "HAPPY"
      assert item =~ "frame-plate"
    end
  end

  describe "the head of the list" do
    test "carries the two facts that are about the list, and the rail does not",
         %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")

      tags =
        render(live)
        |> String.split(~s(class="list-tags))
        |> tl()
        |> Enum.map_join(" ", &(&1 |> String.split("</div>") |> hd()))

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

      # THE BOXES ARE THE FIELDS. They had labels over them — DOING, MOOD —
      # which named what the box obviously was and left the answer squeezed
      # underneath. The placeholder does that job and leaves when answered.
      room = render(live)
      assert room =~ "WHAT ARE YOU UP TO?"
      refute room =~ ">DOING<"
      refute room =~ ">MOOD<"

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
      live |> element(~s(button[phx-click="pick_open"][phx-value-which="mood"])) |> render_click()
      assert render(live) =~ "HEARTBROKEN"
      live |> element(~s(button[phx-click="pick_open"][phx-value-which="mood"])) |> render_click()
      refute render(live) =~ "HEARTBROKEN"

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

      assert %{mood: nil, doing: nil} = Rounds.live(me.id)
    end

    # MANUAL CANCEL, and it is the only way out that changes nothing.
    test "cancelling makes no round at all", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()
      live |> element(~s(button[phx-click="round_cancel"])) |> render_click()

      refute has_element?(live, "#round-form")
      assert Rounds.live(me.id) == nil
    end

    test "a doing and a mood, and the round is numbered", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      render_submit(live, :round_send, %{
        "doing" => "fixing the bike before it rains",
        "mood" => "happy"
      })

      # THE NUMBER IS WHAT IT IS KNOWN BY. Per creator, increasing — a name
      # repeats and is optional, and no two people's are comparable.
      assert %{doing: "fixing the bike before it rains", mood: "happy", number: 1} =
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

      assert %{mood: "hopeful", number: 2} = Rounds.live(me.id)
      assert [%{mood: "hopeful", number: 2}, %{mood: "tired", number: 1}] = Rounds.history(me.id)
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

  describe "the list is live" do
    # THE BUG THIS CATCHES. The only broadcast was per-person, so somebody going
    # round told nobody — a stranger watching the list saw nothing at all until
    # they reloaded. A round changes what is IN other people's lists, and none of
    # that is addressed to anyone.
    #
    # `:land` IS SENT BY HAND. News waits a beat before it joins, so the list
    # never reorders under a finger already moving; the wait is a timer the
    # surface owns and a test drives. Sent straight rather than broadcast, so the
    # two messages are ordered — a pubsub round trip can arrive after the `:land`
    # meant to answer it, and then the skeleton is still standing.
    test "somebody going round redraws a stranger's list without a refresh",
         %{conn: _conn} do
      watcher = passported("funmi", ~w(one two three), "1111")
      teller = person("TELLER")

      {:ok, live, html} = live(check_in(build_conn(), watcher), ~p"/")
      assert html =~ "TELLER"
      refute leader(live) =~ "TELLER"

      round(teller, %{doing: "soup and a film", audience: "public"})
      send(live.pid, :surface_stir)
      send(live.pid, :land)

      # GOING ROUND PULLS THEM TO THE FRONT, and that is what a watcher sees
      # change — the row carries no round text, so the ORDER is the visible half.
      assert leader(live) =~ "TELLER", "the list did not redraw"
      # AND IT ARRIVES WEARING IT. One row at a time, and it fades on its own.
      assert render(live) =~ "is-fresh"
    end

    # AND A VISITOR TOO. They have no passport and therefore no topic of their
    # own, which is exactly why the per-person broadcast could never reach them.
    test "and a visitor's", %{conn: _conn} do
      teller = person("TELLER")
      {:ok, live, _} = live(build_conn(), ~p"/")

      round(teller, %{doing: "a book about rivers", audience: "public"})
      send(live.pid, :surface_stir)
      send(live.pid, :land)

      assert leader(live) =~ "TELLER"
    end

    # A SKELETON STANDS IN THE PLACE FIRST. The couple of seconds between the
    # news and the list taking it in are announced rather than silent — an empty
    # pause would be the same jolt with a delay in front of it.
    test "and says somebody is arriving before they do", %{conn: _conn} do
      {:ok, live, _} = live(build_conn(), ~p"/")
      refute render(live) =~ "scopes-landing"

      send(live.pid, :surface_stir)
      assert render(live) =~ "scopes-landing"

      send(live.pid, :land)
      refute render(live) =~ "scopes-landing"
    end

    # TURNING IT OFF IS ASKING NOT TO BE MOVED. Nothing arrives until you say so,
    # and the count is the offer to catch up rather than a notice.
    test "paused, it counts instead of moving", %{conn: _conn} do
      teller = person("TELLER")
      {:ok, live, _} = live(build_conn(), ~p"/")

      # PAUSING HAS NO CONTROL ON THE SURFACE FOR NOW — the list is always live and
      # the band's dots say so. The machinery underneath is what this guards, so
      # it is driven straight rather than through a button that is not there.
      render_click(live, "toggle_live")
      refute has_element?(live, ~s(#bar.is-live))

      round(teller, %{doing: "a book about rivers", audience: "public"})
      send(live.pid, :surface_stir)

      assert render(live) =~ "1 NEW"
      refute leader(live) =~ "TELLER", "a paused list must not move"
      refute render(live) =~ "scopes-landing"

      live |> element(~s(button[phx-click="catch_up"])) |> render_click()
      assert leader(live) =~ "TELLER"
      refute render(live) =~ "1 NEW"
    end

    # A REDRAW IS NOT A NOTICE. The stir goes to everybody because who may SEE
    # the round is decided on the read; a private one still reaches nobody's list
    # but its own audience.
    test "a private round redraws nothing a stranger can see", %{conn: _conn} do
      watcher = passported("funmi", ~w(one two three), "1111")
      teller = person("TELLER")

      {:ok, live, _} = live(check_in(build_conn(), watcher), ~p"/")

      round(teller, %{doing: "soup and a film", audience: "private"})
      send(live.pid, :surface_stir)
      send(live.pid, :land)

      refute leader(live) =~ "TELLER", "a private round surfaced somebody to a stranger"
    end
  end

  describe "the order of the list" do
    # GOING ROUND PULLS YOU TO THE FRONT, and running out leaves you exactly
    # where you were. Being overtaken is something somebody else did; fading is
    # not, so fading must not move you.
    test "the newest round leads, and expiry does not demote", %{conn: conn, me: me} do
      [{_a, first}, {second_scope, second} | _] = Relationships.held_by(me.id)

      round(first, %{mood: "calm"})
      round(second, %{mood: "happy"})

      {:ok, live, _} = live(conn, ~p"/")
      # THE LABEL, not the name. A row shows one word for a person now — the one
      # you gave them — because two on a line read as a headline over a byline.
      assert leader(live) =~ second_scope.name

      # It runs out — and stays exactly where it was.
      Rounds.stop(second.id)
      send(live.pid, :stir)
      assert leader(live) =~ second_scope.name, "an expired round must not demote anybody"
    end
  end

  describe "refusing to appear" do
    test "hidden removes the round while leaving them in the list", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      [{scope, _} | _] = Relationships.held_by(me.id)
      round(them, %{mood: "happy", doing: "reading"})
      {:ok, _} = People.set_around_hidden(them, true)

      {:ok, live, html} = live(conn, ~p"/")
      assert html =~ scope.name

      settle(live, scope.name)
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

  # THE FIRST REAL ROW. A skeleton wears `scopes-item` too — it has to, or it
  # would not hold the shape it is standing in for — so the leader is the first
  # one that is not it.
  defp leader(live) do
    render(live)
    |> String.split(~s(class="scopes-item))
    |> tl()
    |> Enum.find(&(not (&1 =~ "scopes-landing"))) || ""
  end
end
