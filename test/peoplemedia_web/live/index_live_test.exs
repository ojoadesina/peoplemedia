defmodule PeoplemediaWeb.IndexLiveTest do
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  # THE LIST BELONGS TO SOMEBODY NOW. It used to be nineteen module attributes
  # that every test got for free; a scope is a row joining two people, so a test
  # about the list has to say whose it is. `cast/0` drives the full three-round
  # handshake for each — a relationship left at `scoping` is not one the list
  # shows, and a fixture that quietly produced the wrong state would make every
  # test built on it a lie.
  setup %{conn: conn} do
    me = cast()
    %{conn: check_in(conn, me), me: me}
  end

  test "the surface renders its line and every scoped person", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    assert html =~ "SO YOU DON&#39;T DO LIFE ALONE"
    # the label leads, their own name follows it
    assert html =~ "MUM"
    assert html =~ "SARAH"
    # one row per person, and a band for them to pass through
    assert html |> String.split(~s(class="scopes-item)) |> length() == held_count() + 1
    assert html =~ "focus-box"
  end

  test "a row says what the last letter was, when, and which way it went", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # THE THREE KINDS all reach the surface, and the third is the reason this
    # test exists: a letter is words by default, so "text" is the plain case and
    # a list that only ever draws faces and voices is not showing letters at all.
    # Each kind is one <rect>; only the struck-through one is turned.
    assert html =~ ~s(<rect x="4" y="9" width="16" height="6"></rect>)
    assert html =~ ~s(<rect x="4" y="9" width="6" height="6"></rect>)
    # Not ~s(): the sigil's own delimiter closes on the paren inside rotate().
    assert html =~ "rotate(-45 12 12)"

    # The age of the last letter hangs under the name.
    assert html =~ "scopes-when"

    # BOTH ARROWS, BOTH LIT AND FADED. Their labels are the assertion because
    # they are what the states actually mean — and because an aria-label is the
    # only place a mark drawn in <path> says anything at all.
    assert html =~ "Unread letter from them"
    assert html =~ "Their letter, read"
    assert html =~ "Your letter has been read"
    assert html =~ "Your letter is unread"
  end

  test "a stranger keeps the mark's column but has no letters", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()

    # A letter is written to a SCOPE, so someone you have not scoped has none —
    # no age, no arrows.
    assert unscoped =~ "AMINA"
    refute unscoped =~ "scopes-when"
    refute unscoped =~ "letter-flow"

    # The column is still reserved, though, or every name in this list would sit
    # a mark's width left of every name in the other one — and the two share a
    # scroller and a band.
    assert unscoped =~ "letter-glyph"
  end

  test "the rail is the only measure the page uses", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # Every band of the page wears .rail and nothing else decides its edges. The
    # old surface had five different left edges; this asserts there is one.
    assert html |> String.split(~s(class="rail)) |> length() >= 3

    # And none of the ad-hoc measures that caused the drift survive here: no
    # container padding of its own, no bar spelling the page's width out again.
    refute html =~ "max-w-6xl"
    refute html =~ "calc(min(100vw"
    refute html =~ "px-[1.95rem]"
  end

  test "every row still hands the frame a state, even with nothing to put in it",
       %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # THE ROW CARRIES ITS FRAME AS DATA and always has — the hook reads these on
    # settle. What changed is that presence is no longer a fixture: `state` and
    # `frame` describe a LIVE line, and there is nothing live to describe until
    # Presence lands. So every row reads present-and-empty, which is honest,
    # where it used to read a spread of made-up states.
    assert html =~ ~s(data-state="present")
    assert html =~ ~s(data-frame="empty")
    refute html =~ ~s(data-frame="face")
    refute html =~ ~s(data-state="live")
  end

  test "picking a person lifts them into a header and opens the panel", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    refute html =~ "id=\"panel\""
    refute has_element?(live, "#bar.is-picked")

    # Pressing the band with nothing selected must be inert.
    live |> element(".focus-box") |> render_click()
    refute has_element?(live, "#bar.is-picked")

    # The hook decides WHO; here we stand in for it.
    render_hook(live, "select", %{"index" => 1})
    refute has_element?(live, "#bar.is-picked")

    opened = live |> element(".focus-box") |> render_click()
    assert has_element?(live, "#bar.is-picked")
    assert has_element?(live, "#scopes.is-open")
    assert has_element?(live, "#panel")
    assert opened =~ "DAD"
    assert opened =~ "MICHAEL"
    # The panel names its two views. LETTERS, not RECORD: "record" names the act
    # of capturing, which a typed letter never went through.
    assert opened =~ "LETTERS"
    assert opened =~ "LIVE"
    refute opened =~ "RECORD"

    live |> element(".focus-box") |> render_click()
    refute has_element?(live, "#panel")
  end

  test "the panel is named for what it is, in markup as well as on screen", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    # A thread with a text letter in it, so the third kind reaches the panel too.
    render_hook(live, "select", %{"index" => 4})
    opened = live |> element(".focus-box") |> render_click()

    # "presence" named the medium, which made a written letter unnameable. The
    # ids, the classes and the hook say panel now, not just the heading.
    for id <- ~w(panel panel-letters panel-scroll panel-item panel-when),
        do: assert(opened =~ id)

    assert opened =~ ~s(phx-hook="Panel")
    refute opened =~ "presence-"
    refute opened =~ "PresencePanel"

    # The panel's own empty band is the same ellipsis the list's is.
    assert opened =~ "..."
    assert opened =~ "rotate(-45 12 12)"

    # THE FRAME IS HIDDEN BUT NOT REMOVED, and that is load-bearing rather than
    # incidental. app.css takes it out of sight when the panel opens — it
    # answers the band, and the band has become a header — but the ELEMENT has
    # to stay, because hiding a media element does not silence it and only
    # scopes.ts can tear the media down. Render it conditionally and a voice
    # goes on playing over an open panel from a box nobody can see or press.
    assert opened =~ ~s(id="frame")
  end

  test "losing the selection closes the panel with it", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    render_hook(live, "select", %{"index" => 0})
    live |> element(".focus-box") |> render_click()
    assert has_element?(live, "#panel")

    render_hook(live, "deselect", %{})
    refute has_element?(live, "#panel")
    refute has_element?(live, "#bar.is-picked")
  end

  test "the two boxes are the head of the list, and each flips one axis", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    # WHERE, and WHICH OF THEM. The place box names the place; the population box
    # names the population you are inside and carries its own count.
    assert boxes_say(live) =~ "FINLAND"
    assert boxes_say(live) =~ "6 SCOPES"

    # THE POPULATION BOX SWAPS, and never leaves the people. It shows where you
    # ARE rather than offering both — one box, not a segmented pair.
    live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert boxes_say(live) =~ "122 UNSCOPES"
    # One box, so the population it swapped OUT of is not on screen at all.
    # (It cannot refute "SCOPES" — "UNSCOPES" contains it.)
    refute boxes_say(live) =~ "6 SCOPES"
    assert has_element?(live, "#frame")

    # THE PLACE BOX SWAPS WHAT THE LIST HOLDS. The roll opens unselected, so the
    # box reads WORLD — no country chosen — and the world's own totals with it.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    refute has_element?(live, "#frame")
    assert boxes_say(live) =~ "WORLD"
    assert boxes_say(live) =~ "33256 UNSCOPES"
  end

  test "the band moves the place box but commits nothing", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    live |> element(~s(button[phx-click="place_box"])) |> render_click()

    # A country scrolling through the band updates the box AND its counts, so
    # you can read a place's two populations without leaving the roll.
    render_hook(live, "select", %{"index" => 1})
    assert boxes_say(live) =~ "NIGERIA"
    assert boxes_say(live) =~ "41 SCOPES"

    # Still in the world. The band alone commits nothing, and neither does the
    # band's own press.
    live |> element(".focus-box") |> render_click()
    refute has_element?(live, "#frame")

    # AND THE WAY OUT THAT CHANGES NOTHING leaves with what you came in with.
    live |> element(~s(button[phx-click="cancel_place"])) |> render_click()
    assert has_element?(live, "#frame")
    assert boxes_say(live) =~ "FINLAND"
    assert boxes_say(live) =~ "6 SCOPES"
  end

  test "either box is a door back, and both take the place with them", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    # THE PLACE BOX commits what settled and keeps the population you had.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    render_hook(live, "select", %{"index" => 1})
    scoped = live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert boxes_say(live) =~ "NIGERIA"
    assert boxes_say(live) =~ "41 SCOPES"
    assert scoped =~ "MUM"
    refute has_element?(live, "#panel")

    # THE POPULATION BOX commits it too, and swaps population on the way — one
    # press answering both halves, which is what the two count boxes used to do.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})
    unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert boxes_say(live) =~ "BRAZIL"
    assert boxes_say(live) =~ "2652 UNSCOPES"
    # A stranger only the unscoped world holds, so the list really swapped.
    assert unscoped =~ "AMINA"
  end

  test "the cancel is the only exit while the roll of places is open", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    refute has_element?(live, ~s(button[phx-click="cancel_place"]))

    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert has_element?(live, ~s(button[phx-click="cancel_place"]))
    assert has_element?(live, ~s(button[phx-click="place_box"][aria-pressed="true"]))

    # WORLD is a choice like any other, so pressing the box on an empty band
    # commits it rather than being inert.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert boxes_say(live) =~ "WORLD"
    assert boxes_say(live) =~ "232 SCOPES"
    refute has_element?(live, ~s(button[phx-click="cancel_place"]))
  end

  test "an unread mark keeps its full voice; the rest are held quiet", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # is-lit rides only on a mark whose row has an unopened letter, and it is
    # what app.css exempts from the resting opacity. Dimming those too was the
    # mistake in between: it flattened the one difference the marks are for.
    lit = ~r/letter-glyph[^"]*is-lit[^"]*text-primary-600/
    assert Regex.scan(lit, html) |> length() == 3

    # And no mark is lit without being terracotta, or vice versa.
    marks = Regex.scan(~r/class="(letter-glyph[^"]*)"/, html, capture: :all_but_first)

    for [m] <- marks,
        do: assert(String.contains?(m, "is-lit") == String.contains?(m, "text-primary-600"))
  end

  test "the empty band says nothing yet, and does not say it with the mark", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # AN ELLIPSIS, NOT "--". The app's mark is a pair of dashes and the voice
    # glyph is one bar, so two dashes in terracotta at the head of the list read
    # as the logo turning up in the middle of the page.
    assert html =~ "..."
    refute html |> String.replace(~r/<[^>]*>/, " ") =~ ~r/(?<!\.)--(?!-)/
  end

  test "exactly one of the two boxes is lit, and it is the one the list obeys", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    wash = ~r/(list-place|list-scope)[^"]*bg-primary-600\/15/

    # Over people the population box is lit and the place box is not: a
    # population is READ OUT OF a place, so lighting both would claim two things
    # are being chosen when only one is.
    assert Regex.scan(wash, boxes_html(live), capture: :all_but_first) == [["list-scope"]]

    # Over the roll of places it swaps — and the population box goes quiet
    # precisely because its count is now being driven by the band.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert Regex.scan(wash, boxes_html(live), capture: :all_but_first) == [["list-place"]]
  end

  test "the boxes answer the band from the rail, not the head of the column", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    # The cluster is placed by app.css against the stage box, so it carries no
    # position and no width of its own — either here would be a second opinion
    # about where the rail is. Its OWN class attribute, not the subtree: the
    # frame's replay control is legitimately absolute inside it.
    boxes = boxes_html(live)
    own = Regex.run(~r/<div class="(scope-boxes[^"]*)"/, boxes, capture: :all_but_first)
    refute hd(own) =~ "absolute"
    refute hd(own) =~ "ml-auto"
    refute hd(own) =~ "--list-w"

    # Three boxes, flush and in one row: place, population, then the frame on
    # the rail's right edge.
    assert boxes =~ "list-place"
    assert boxes =~ "list-scope"
    assert boxes =~ ~s(id="frame")
    refute boxes =~ "-ml-3"
  end

  test "a place is one line, shouted, and its rows close up to suit", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")
    assert html =~ "h-(--row-h)"

    places = live |> element(~s(button[phx-click="place_box"])) |> render_click()

    # UPPERCASE like every other word on this surface. The fixtures store
    # "Finland" because that is the country's name; the list is a list.
    assert places =~ "NIGERIA"
    refute places =~ ">\n                  Nigeria"

    # And a shorter row, because a place has no age hung under it. At the
    # people row's height the words sat further apart than the band is tall.
    assert places =~ "h-(--place-h)"
    refute places =~ "h-(--row-h)"
  end

  test "the act opens the launcher, and is the only control that closes it", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # ONE BUTTON, THREE ANSWERS — plus, cross, back — so there is no second
    # control a thumb's width away arguing about the same panel.
    assert html =~ ~s(id="act")
    assert html =~ "act-mark"
    assert html =~ "act-back"
    assert html =~ ~s(aria-expanded="false")
    refute html =~ "panel-close"
  end

  test "the fab panel is one overlay with a room per door", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # THE REGISTRY: a body per room, a cell per door, joined by name alone. If
    # a door ever names a room that does not exist, this is what catches it.
    doors =
      Regex.scan(~r/data-panel-open="([a-z]+)"/, html, capture: :all_but_first) |> List.flatten()

    rooms =
      Regex.scan(~r/data-panel-body="([a-z]+)"/, html, capture: :all_but_first) |> List.flatten()

    assert "launcher" in rooms
    assert doors != []
    assert Enum.all?(doors, &(&1 in rooms)), "a launcher cell opens a room that is not there"

    # It is OPAQUE. The panel it came from floated on a 90% wash because the
    # thing behind it was a map you read through; here it is a list of names.
    assert html =~ "fab-ground absolute inset-0 bg-light-50 dark:bg-dark-950"
    refute html =~ "bg-white/90"
  end

  test "the launcher says whether you are checked in", %{conn: conn, me: me} do
    # Checked in, the launcher greets you by name.
    {:ok, _live, html} = live(conn, ~p"/")
    assert html =~ String.upcase(me.name)
    refute html =~ "NOT CHECKED IN"

    # A VISITOR IS OFFERED THE WAY IN rather than a manager for a passport that
    # does not exist. `build_conn/0` because the case checks everyone in.
    {:ok, _live, html} = live(build_conn(), ~p"/")
    assert html =~ "NOT CHECKED IN"
    assert html =~ "CHECK IN"
  end

  test "a visitor holds nobody, and opens on the list that has people in it",
       %{conn: _conn} do
    {:ok, _live, html} = live(build_conn(), ~p"/")

    # SCOPED is the list's subject and the right default for anyone who holds
    # people — but for a visitor it is empty, and opening on an empty list makes
    # an app look broken when it is merely new. So the strangers lead.
    assert html =~ "UNSCOPES"
    # Everyone the cast made is a stranger to a visitor, including the owner.
    assert html |> String.split(~s(class="scopes-item)) |> length() ==
             held_count() + stranger_count() + 1 + 1
  end

  test "the act sits on the app's own edge, opposite the mark", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # Built like the masthead — fixed, full width, one .rail inside — so it
    # lands on the app's left edge without measuring anything. z-50 puts it
    # ABOVE the panel it controls: the ground is opaque, and at z-30 the thing
    # you press to close a room was painted over by the room.
    # ~s|...|, not ~s(...): the paren in `bottom-(` closes the sigil early.
    assert html =~
             ~s|class="app-foot pointer-events-none fixed inset-x-0 bottom-(--foot-bottom) z-50"|

    # It opens the LAUNCHER now rather than writing directly. Writing is one
    # door among several, and a button that did only that would have to be
    # joined by a second the day a second door existed.
    assert html =~ "Open the launcher"

    # Its own size, not the band's: it sits alone in the opposite corner with
    # nothing beside it to rhyme with, so it is sized for being pressed.
    assert html =~ "size-(--act-h)"

    # THE ONLY SOLID FILL ON THE SURFACE — everything else here is a wash, and
    # this is the one act rather than a state. A step off full strength, and
    # opposite ways in the two themes: lighter on cream, darker on black.
    assert html =~ "bg-primary-500 text-primary-50"
    assert html =~ "dark:bg-primary-600"

    # A THIN PLUS, two square-ended bars. It began as the voice bar crossed with
    # itself — the literal 16x6 every kind mark is cut from — and at a quarter of
    # the box, cut pale out of solid colour, that was a slab rather than a mark.
    assert html =~ ~s(<rect x="4" y="10.25" width="16" height="3.5"></rect>)
    assert html =~ ~s(<rect x="10.25" y="4" width="3.5" height="16">)
  end

  # WHAT THE BOXES SAY, with the markup taken out of the way. Each box is a
  # button of its own and the number and its word are separate nodes, so no
  # substring of the raw HTML holds a whole phrase. Stripping the tags and
  # collapsing the whitespace asks the question the tests actually mean: read
  # aloud, does this cluster name a place and a population of it.
  defp boxes_say(live) do
    live
    |> boxes_html()
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp boxes_html(live), do: live |> element(".scope-boxes") |> render()
end
