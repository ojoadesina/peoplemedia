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
      round(them, %{doing: "something"})

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
      round(them, %{doing: "something"})

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
    # THE BLOCK SAYS THE LAST THING SAID IN THE ROUND, and only that. It carried a
    # mood chip once, and before that a title given before anybody had spoken —
    # the least informed sentence in the round, on its most prominent line.
    test "the word block says what was said, and holds no colour", %{conn: conn, me: me} do
      [{scope, them} | _] = Relationships.held_by(me.id)
      {:ok, round} = Rounds.go(them.id)
      {:ok, _} = Peoplemedia.Words.say(round.id, them.id, "borscht, third attempt")

      {:ok, live, _} = live(conn, ~p"/")

      item = item_for(live, scope.name)
      assert item =~ "BORSCHT, THIRD ATTEMPT"
      refute item =~ ~s(data-family=)
    end

    # A ROUND SAYS NOTHING OF ITS OWN, ANYWHERE.
    #
    # It carried a title for a while — three text fields, then one, then none.
    # Each cut was the same argument taken one step further: a summary of a thing
    # written by somebody who had not said anything yet is the least informed
    # sentence in the round, and it was being given the most prominent line of it.
    #
    # WHAT IS SAID IN IT IS WHAT IT IS. The word block carries the last of those,
    # and stands empty until somebody speaks — which reads correctly: here is
    # somebody, and nobody has said anything yet.
    test "and a round with nothing said in it says nothing", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "BIG BROTHER")

      # BIG BROTHER IS ROUND AND NOBODY HAS SPOKEN IN IT. The item is ONE block:
      # no second block, and no stroke joining it to one. It used to draw both
      # either way and fall back to whatever else it could find, which put a
      # sentence nobody had said in the most prominent line of the item.
      item = item_for(live, "BIG BROTHER")
      assert item =~ ~s(class="frame )
      refute item =~ ~s(class="word )

      # AND NOT A COUNT EITHER. Nothing was said, so there is nothing to count
      # and no deck to draw — a badge reading zero is a badge that has never
      # meant anything.
      refute item =~ ~s(class="word-flow )
    end

    # WHAT WAS SAID IS THE SECOND BLOCK, and the block is only there because
    # something was said in it.
    test "and a round with words in it carries them", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "DAD")

      item = item_for(live, "DAD")
      assert item =~ ~s(class="word )
      assert item =~ "JUST FINISHED THE MARKING"
      # THE ARROWS SAY WHOSE VOICES ARE IN IT. Only theirs is, so only the
      # incoming one is drawn.
      assert item =~ "Somebody has spoken in this round"
      refute item =~ "You have spoken in this round"
    end

    test "nothing at all for somebody who is not here", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      settle(live, "COACH")

      # NO ROUND, NO WORD BLOCK. It used to draw one either way and fall back to a
      # standing status, which read exactly like something somebody had said and
      # was not. Where there are no words there is no block and no stroke.
      item = item_for(live, "COACH")
      refute item =~ "HAPPY"
      refute item =~ ~s(class="word )
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

      assert tags =~ "RELATIONSHIPS"
    end
  end

  describe "going round" do
    test "the form is the shape of what it makes", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      refute has_element?(live, "#round-form")

      live |> element("#act") |> render_click()

      # IN PLACE. The list is still there underneath — a panel would have hidden
      # the very people the round exists to reach.
      assert has_element?(live, "#round-form")
      assert has_element?(live, ".scopes-item")

      # ONE FIELD, AND A HEAD HELD OPEN ABOVE IT. A round has no name to type any
      # more — it is known by when it was made — so the block that would have
      # taken one is empty on purpose: it is where a live capture will go. Drawn
      # rather than left out, because the form is the SHAPE of what it makes and
      # what it makes is two blocks.
      room = render(live)
      assert has_element?(live, "#round-word")
      refute has_element?(live, "#round-name")
      refute room =~ "WHAT IS THIS ROUND?"

      # AND THE BAND LEAVES THE LINE IT IS STANDING ON. They occupy the same place
      # by design, and the band's wash showing through put a terracotta strip
      # across a form that is not a selection.
      assert has_element?(live, "#bar.invisible")

      # AND NO MOOD, ANYWHERE.
      refute room =~ "HEARTBROKEN"
      refute has_element?(live, ~s(button[phx-click="pick_open"]))

      render_submit(live, :round_send, %{"word" => "third attempt at this"})

      # THE ROUND AND ITS FIRST WORD IN ONE PRESS. Going round and then saying
      # something were two acts a moment apart, and the second is the reason for
      # the first.
      round = Rounds.live(me.id)
      assert [%{body: "third attempt at this"}] = Peoplemedia.Words.thread(round.id)
      refute has_element?(live, "#round-form"), "sending closes the form"
    end

    # LEFT BLANK, IT STILL MAKES THE ROUND. "I am here" is the smallest true
    # thing this app exists to let anybody say, and a round with nothing said in
    # it yet is the commonest state there is.
    test "and the first word is optional", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{"word" => "   "})

      round = Rounds.live(me.id)
      assert round
      assert Peoplemedia.Words.thread(round.id) == []
    end

    # EVERY FIELD IS OPTIONAL, so there is nothing to refuse. An empty round is
    # "I am here and open to being joined" — the smallest true thing anybody can
    # say here, and the one this surface exists for.
    test "an empty round is a real round", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{})

      assert %{number: 1} = Rounds.live(me.id)
    end

    # MANUAL CANCEL, and it is the only way out that changes nothing.
    test "cancelling makes no round at all", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()
      live |> element(~s(button[phx-click="round_cancel"])) |> render_click()

      refute has_element?(live, "#round-form")
      assert Rounds.live(me.id) == nil
    end

    test "and the round is numbered", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element("#act") |> render_click()

      render_submit(live, :round_send, %{})

      # THE NUMBER IS WHAT IT IS KNOWN BY. Per creator, increasing — a name
      # repeats and is optional, and no two people's are comparable.
      assert %{number: 1} = Rounds.live(me.id)
    end

    # GOING ROUND IS A NEW ROW EVERY TIME. The old one keeps its words and its
    # place in the history; this one is simply newer.
    test "twice keeps both, and the newest surfaces", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{})

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{})

      assert %{number: 2} = Rounds.live(me.id)
      # READ AS THEMSELVES. `history/3` filters by audience like every other
      # round read, and these were made on the PEOPLE tab — private, to the
      # people this person holds. Your own rounds are always yours to see.
      assert [%{number: 2}, %{number: 1}] = Rounds.history(me.id, me.id)
    end

    # THE AUDIENCE IS THE TAB YOU ARE STANDING ON, never a question. PEOPLE is
    # everyone; RELATIONSHIPS is the people you hold. Offering a control for it
    # would be asking somebody to restate where they already are.
    test "the people tab goes round publicly", %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      live |> element(~s(button[phx-click="scope_box"])) |> render_click()
      assert render(live) =~ "PEOPLE"

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{})

      assert %{audience: "public", target_id: nil} = Rounds.live(me.id)
    end

    test "and the relationships tab goes round with the people you hold",
         %{conn: conn, me: me} do
      {:ok, live, _} = live(conn, ~p"/")
      assert render(live) =~ "RELATIONSHIPS"

      live |> element("#act") |> render_click()
      render_submit(live, :round_send, %{})

      assert %{audience: "private", target_id: nil} = Rounds.live(me.id)
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

      round(first, %{doing: "something"})
      round(second, %{doing: "something"})

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
      {:ok, round} = Rounds.go(them.id)
      {:ok, _} = Peoplemedia.Words.say(round.id, them.id, "reading, still")
      {:ok, _} = People.set_around_hidden(them, true)

      {:ok, live, html} = live(conn, ~p"/")

      # THEY STAY IN THE LIST AND THE ROUND GOES. Hidden is about the round, not
      # about the person — so the name is there and the word block under it is not.
      assert html =~ scope.name
      item = item_for(live, scope.name)
      refute item =~ "READING, STILL"
      refute item =~ ~s(class="word )
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
