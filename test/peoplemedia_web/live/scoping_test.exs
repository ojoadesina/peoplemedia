defmodule PeoplemediaWeb.ScopingTest do
  @moduledoc """
  Swipe a stranger, name them, and watch the handshake move. The context tests
  prove the three rounds; this proves the surface reaches them — and that the
  swipe is offered on exactly the rows it makes sense on.
  """
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Peoplemedia.{Notifications, Relationships}

  setup %{conn: conn} do
    me = cast()
    %{conn: check_in(conn, me), me: me}
  end

  # THE TWO WORDS THE SWIPE UNCOVERS, in order: what the tie can become, and
  # WRITE. Markup taken out of the way — asserting on rendered indentation is
  # asserting on the formatter.
  defp acts_of(row) do
    Regex.scan(~r/<button[^>]*class="row-scope.*?<\/button>/s, row)
    |> List.flatten()
    |> Enum.map(fn b ->
      b |> String.replace(~r/<[^>]*>/, " ") |> String.replace(~r/\s+/, " ") |> String.trim()
    end)
  end

  # The tie's own word — the first of the two.
  defp act_of(row), do: acts_of(row) |> List.first()

  # The scope room's two controls, on their own. The attribute is matched with a
  # space before and nothing word-like after, because Tailwind's `disabled:`
  # VARIANT sits in the class list either way — a plainer match reads that as
  # the attribute and passes whether or not the control is actually shut.
  defp field_in(html), do: Regex.run(~r/<input[^>]*name="label"[^>]*>/, html) |> List.first()

  defp forward_in(html),
    do: Regex.run(~r/<button[^>]*form="scope-form".*?>/s, html) |> List.first()

  defp stranger_row(html) do
    html
    |> then(&Regex.scan(~r/<li [^>]*class="scopes-item.*?<\/li>/s, &1))
    |> List.flatten()
    |> Enum.find(&(&1 =~ "row-scope"))
  end

  describe "the swipe" do
    test "each row offers the one act that applies to it", %{conn: conn} do
      # A STRANGER CAN BE SCOPED. That is the only thing you can do to a name
      # you do not hold.
      {:ok, live, _} = live(conn, ~p"/")
      unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()

      rows = Regex.scan(~r/<li [^>]*class="scopes-item.*?<\/li>/s, unscoped) |> List.flatten()
      assert length(rows) == stranger_count()

      # TWO ACTS ON EVERY ROW. The first is what the tie can become and changes
      # with it; the second is always WRITE, because who may write to whom is a
      # question about permission this app has not answered — and hiding the
      # button was answering it "never".
      assert Enum.all?(rows, &(acts_of(&1) == ["SCOPE", "WRITE"]))
      assert Enum.all?(rows, &(&1 =~ ~s(data-open-room="scope")))

      # SOMEONE YOU HOLD CAN BE LET GO OF, which is the act that had no button
      # at all — scoping was the one decision here you could not take back.
      {:ok, _live, scoped} = live(conn, ~p"/")
      rows = Regex.scan(~r/<li [^>]*class="scopes-item.*?<\/li>/s, scoped) |> List.flatten()
      assert rows != []
      assert Enum.all?(rows, &(acts_of(&1) == ["UNSCOPE", "WRITE"]))
      assert Enum.all?(rows, &(&1 =~ ~s(data-open-room="write")))
    end

    test "the row is a two-page snap scroller and nothing more", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      html = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
      row = stranger_row(html)

      # The browser does the dragging, the momentum and the resting.
      assert row =~ "snap-x"
      assert row =~ "snap-mandatory"
      assert row =~ "overscroll-x-contain"
      # Two pages: the row, and the action.
      assert row |> String.split("snap-start") |> length() == 3
    end

    test "the press tells the server WHO and the hook WHICH ROOM", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      html = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
      row = stranger_row(html)

      # Neither half can do this alone: the panel's open state lives in the
      # browser and the target lives in the process.
      assert row =~ ~s(phx-click="pick_person")
      assert row =~ ~s(data-open-room="scope")
    end
  end

  describe "scoping someone" do
    test "asking twice tells you so instead of asking them twice", %{conn: conn, me: me} do
      them = person("NEWCOMER")
      {:ok, live, _} = live(conn, ~p"/")

      render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})
      render_submit(live, :scope_send, %{"label" => "cousin"})
      assert Notifications.unread_count(them.id) == 1

      # THE SECOND ASK IS NOT A SECOND ROW and must not be a second knock. The
      # context has always refused the write; the surface used to notify anyway,
      # because it matched `{:ok, _}` and threw the answer away.
      {:ok, again, _} = live(conn, ~p"/")
      render_click(again, :pick_person, %{"id" => them.id, "act" => "scope"})
      render_submit(again, :scope_send, %{"label" => "cousin"})
      assert Notifications.unread_count(them.id) == 1

      # And somebody you already hold is refused outright.
      [{_scope, held} | _] = Relationships.held_by(me.id)
      render_click(again, :pick_person, %{"id" => held.id, "act" => "scope"})
      assert render_submit(again, :scope_send, %{"label" => "cousin"}) =~ "YOU ALREADY HOLD THEM"
    end

    test "names them, asks, and tells them", %{conn: conn, me: me} do
      them = person("NEWCOMER")

      {:ok, live, _} = live(conn, ~p"/")
      html = render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})
      assert html =~ "NEWCOMER"
      assert html =~ "WHAT DO YOU CALL THEM?"

      render_submit(live, :scope_send, %{"label" => "cousin"})

      # ROUND ONE ONLY. It is `scoping`, not `scoped` — they have not answered,
      # and a request that seated itself would not be a request.
      refute Relationships.related?(me.id, them.id)
      %{outgoing: [out]} = Relationships.pending_scopes_for(me.id)
      assert out.phase == "waiting_back"
      assert out.my_label == "COUSIN"

      # AND THEY ARE TOLD, durably — a request riding only on a live broadcast
      # would be lost on anyone who was not looking.
      assert Notifications.unread_count(them.id) == 1
    end

    test "a scope with no name is refused, because the name IS the act",
         %{conn: conn, me: me} do
      them = person("NEWCOMER")
      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert render_submit(live, :scope_send, %{"label" => "   "}) =~ "WHAT DO YOU CALL THEM?"
      assert Relationships.pending_scopes_for(me.id) == %{incoming: [], outgoing: []}
    end

    test "a visitor cannot scope anyone", %{} do
      them = person("NEWCOMER")
      {:ok, live, _} = live(build_conn(), ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert render_submit(live, :scope_send, %{"label" => "cousin"}) =~ "CHECK IN FIRST"
    end

    test "and the room says so before the press, not after", %{conn: conn} do
      them = person("NEWCOMER")

      # THE SERVER'S REFUSAL IS THE ONE THAT MATTERS and is not going anywhere —
      # see the test above. But being told to check in only after you have
      # thought of a name and typed it is the app wasting your time to say
      # something it knew when the room opened.
      {:ok, out, _} = live(build_conn(), ~p"/")
      shut = render_click(out, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert shut =~ "CHECK IN TO SCOPE ANYONE"
      assert field_in(shut) =~ ~r/\sdisabled(?![:\w-])/
      assert forward_in(shut) =~ ~r/\sdisabled(?![:\w-])/
      # And a way to fix it from where you are standing.
      assert shut =~ ~s(data-open-room="passport")

      {:ok, in_, _} = live(conn, ~p"/")
      open = render_click(in_, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert open =~ "WHAT DO YOU CALL THEM?"
      refute field_in(open) =~ ~r/\sdisabled(?![:\w-])/
      refute forward_in(open) =~ ~r/\sdisabled(?![:\w-])/
    end
  end

  describe "the other side finds out" do
    test "answering a handshake reaches the asker's open screen", %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(me.id, them.id, "COUSIN")

      # MY screen, showing the request I sent, sitting open.
      {:ok, mine, html} = live(conn, ~p"/")
      assert html =~ "YOU CALL THEM “COUSIN” · WAITING"

      # THEY answer from somewhere else entirely — another session, another
      # machine. Nothing about my screen is involved in it.
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")
      {:ok, _} = Peoplemedia.Notifications.notify(me.id, "scope_back", them.id)

      # A HANDSHAKE HAS TWO SIDES AND ONLY ONE OF THEM PRESSES ANYTHING. Without
      # the nudge this said "waiting" until I reloaded — the two of us reading
      # different versions of the same act.
      assert render(mine) =~ "SCOPED YOU BACK “OJO” — FINALISE"
    end

    test "the count on the door goes down when the room is opened", %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")
      {:ok, _} = Peoplemedia.Notifications.notify(me.id, "scope_request", them.id)

      {:ok, live, html} = live(conn, ~p"/")
      # The count rides the act itself — the only part of the app you can see
      # while doing something else.
      assert html =~ ~s(launcher-badge)
      assert Peoplemedia.Notifications.unread_count(me.id) == 1

      render_hook(live, "seen_scoping", %{})
      assert Peoplemedia.Notifications.unread_count(me.id) == 0
      refute render(live) =~ ~s(launcher-badge)
    end
  end

  describe "the row keeps up" do
    # The word on the uncovered action for one person, whichever list they are
    # in — :absent when that list does not hold them at all.
    defp act_for(html, who) do
      Regex.scan(~r/<li [^>]*class="scopes-item.*?<\/li>/s, html)
      |> List.flatten()
      |> Enum.find(&(&1 =~ who))
      |> case do
        nil -> :absent
        row -> act_of(row)
      end
    end

    defp unscoped(live), do: live |> element(~s(button[phx-click="scope_box"])) |> render_click()

    test "it says what is outstanding, so a second ask is never offered",
         %{conn: conn, me: me} do
      them = person("NEWCOMER")
      {:ok, live, _} = live(conn, ~p"/")

      assert act_for(unscoped(live), "NEWCOMER") == "SCOPE"

      render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})
      render_submit(live, :scope_send, %{"label" => "cousin"})

      # THIS IS WHERE A DOUBLE SCOPE CAME FROM. The room already opened at the
      # true step and refused a second ask — but being offered the act and then
      # told no is worse than never being offered it. The row is where you
      # decide, so the row is where it has to be true.
      assert act_for(render(live), "NEWCOMER") == "ASKED"

      # THEY ANSWER FROM SOMEWHERE ELSE, and my row has to hear about it — this
      # is the notify their own handler sends. Asserting it still said ASKED
      # would be asserting that the update does not arrive.
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")
      {:ok, _} = Notifications.notify(me.id, "scope_back", them.id)
      assert act_for(render(live), "NEWCOMER") == "FINALISE"

      render_click(live, :scope_accept, %{"id" => them.id})

      # And once it lands they leave the unscoped list entirely.
      assert act_for(render(live), "NEWCOMER") == :absent
      assert act_for(unscoped(live), "NEWCOMER") == "UNSCOPE"
      assert Relationships.related?(me.id, them.id)
    end

    test "somebody who asked YOU is asking, not waiting", %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, live, _} = live(conn, ~p"/")
      assert act_for(unscoped(live), "INBOUND") == "ANSWER"
    end
  end

  describe "letting go" do
    test "unscoping drops both sides to strangers, and keeps the tie tracked",
         %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, live, _} = live(conn, ~p"/")

      render_click(live, :unscope, %{"id" => them.id})

      refute Relationships.related?(me.id, them.id)
      # NOT DELETED. The same place a decline leaves two people: tracked, hidden
      # and re-askable, so "have we ever spoken?" keeps an answer.
      assert {:ok, :sent} = Relationships.request_scope(me.id, them.id, "AGAIN")
    end

    test "the row swaps to SCOPE once they are let go", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, live, _} = live(conn, ~p"/")

      render_click(live, :unscope, %{"id" => them.id})
      unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()

      assert act_for(unscoped, String.upcase(them.name)) == "SCOPE"
    end

    test "the first press never reaches here — the browser holds it", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")

      # THE ARMING IS ENTIRELY A FACT ABOUT A GESTURE, so it lives in the page:
      # the hook stops the first click before LiveView sees it and asks in the
      # toast. Putting it on the server would mean a half-armed process that a
      # reload or a second tab could get out of step with.
      row = Regex.scan(~r/<li [^>]*class="scopes-item.*?<\/li>/s, html) |> List.flatten() |> hd()
      assert row =~ ~s(data-unscope=)
      assert row =~ ~s(phx-click="unscope")
      assert html =~ ~s(id="toast")
      assert html =~ ~s(phx-hook="Confirm")

      hook = File.read!("assets/js/hooks/confirm.ts")
      assert hook =~ "e.stopPropagation()", "the first press must not reach the server"
      assert hook =~ "data-unscope"
    end

    test "a visitor is told to check in rather than crashing", %{} do
      them = person("SOMEBODY")
      {:ok, live, _} = live(build_conn(), ~p"/")
      assert render_click(live, :unscope, %{"id" => them.id}) =~ "CHECK IN FIRST"
    end
  end

  describe "the room opens at the step that is outstanding" do
    test "somebody you have already asked cannot be asked again", %{conn: conn, me: me} do
      them = person("NEWCOMER")
      {:ok, :sent} = Relationships.request_scope(me.id, them.id, "COUSIN")

      {:ok, live, _} = live(conn, ~p"/")
      html = render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      # NO FIELD AT ALL. A naming field here invites an act that has already
      # happened, and the only thing between that and a duplicate was the
      # context refusing it afterwards. An unreachable duplicate beats a
      # politely declined one.
      assert html =~ "WAITING ON THEM"
      assert html =~ ~s(YOU CALL THEM “COUSIN”)
      refute html =~ ~s(name="label")
      # Withdrawing is the small cross in the foot, beside the way out — not a
      # full-width band halfway up the room.
      assert html =~ ~s(phx-click="scope_reject")
      assert html =~ ~s(aria-label="Decline")
    end

    test "somebody who asked YOU opens on the answer, not on a fresh ask",
         %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, live, _} = live(conn, ~p"/")
      html = render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert html =~ "THEY CALL YOU “FRIEND” — AND YOU CALL THEM?"
      assert html =~ ~s(name="label")
      assert html =~ ~s(phx-submit="scope_back")
      # YES AND NO IN ONE ROW. They were a screen apart and drawn as different
      # kinds of object, which is not how two answers to one question should read.
      assert html =~ ~s(aria-label="Decline")
    end

    test "a handshake they answered opens on the seal, with both names",
         %{conn: conn, me: me} do
      them = person("OUTBOUND")
      {:ok, _} = Relationships.request_scope(me.id, them.id, "COUSIN")
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")

      {:ok, live, _} = live(conn, ~p"/")
      html = render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert html =~ "YOU CALL THEM"
      assert html =~ "COUSIN"
      assert html =~ "THEY CALL YOU"
      assert html =~ "OJO"
      # Sealing decides nothing that needs typing, so there is no form.
      refute html =~ ~s(name="label")
      assert html =~ ~s(phx-click="scope_accept")
    end

    test "the scoping room's rows are lines that lead somewhere, not forms",
         %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, _live, html} = live(conn, ~p"/")
      room = Regex.run(~r/data-room="scoping".*?(?=data-room=")/s, html) |> List.first()

      # A field and two buttons crammed into a list row is why they overlapped.
      assert room =~ ~s(phx-click="open_scope")
      refute room =~ ~s(name="label")
      refute room =~ ~s(phx-submit="scope_back")
    end
  end

  describe "the scoping room" do
    test "says nothing is in motion when nothing is", %{} do
      # SOMEBODY WITH NO TIES AT ALL. The cast holds six people, and settled
      # scopes are listed here now — so "nothing in motion" is only true of a
      # passport on its first morning, which is exactly who this line is for.
      alone = passported("newcomer", ~w(alpha beta gamma), "1111")
      {:ok, _live, html} = live(check_in(build_conn(), alone), ~p"/")
      assert html =~ "NOTHING IN MOTION"
    end

    test "shows what landed, so finishing a scope leaves evidence", %{conn: conn, me: me} do
      # Finalising used to send this room back to NOTHING IN MOTION — true, since
      # a settled scope is not in flight, and a terrible answer to "did that
      # work?".
      {:ok, _live, html} = live(conn, ~p"/")
      room = Regex.run(~r/data-room="scoping".*?(?=data-room=")/s, html) |> List.first()

      assert room =~ "SCOPED · #{length(Relationships.held_by(me.id))}"
      assert room =~ "MUM"
      assert room =~ "SARAH"
      refute room =~ "NOTHING IN MOTION"
    end

    test "shows both directions, and whose move it is", %{conn: conn, me: me} do
      # One I asked for, and one asked of me.
      mine = person("OUTBOUND")
      theirs = person("INBOUND")
      {:ok, _} = Relationships.request_scope(me.id, mine.id, "COUSIN")
      {:ok, _} = Relationships.request_scope(theirs.id, me.id, "FRIEND")

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "INCOMING · 1"
      assert html =~ "OUTGOING · 1"
      assert html =~ "INBOUND"
      assert html =~ "CALLS YOU “FRIEND” — ANSWER"
      assert html =~ "OUTBOUND"
      assert html =~ "YOU CALL THEM “COUSIN” · WAITING"
      refute html =~ "NOTHING IN MOTION"
    end
  end
end
