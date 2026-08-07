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
    # one item per person, and no band for them to pass through
    assert html |> String.split(~s(class="scopes-item)) |> length() == held_count() + 1
    assert html =~ "scopes-item"
  end

  # ONE NAME AND TWO MARKS, AND THE MARKS ARE NOT WORDS.
  #
  # IT USED TO SAY A GREAT DEAL MORE IN WORDS — their own name beside the one you
  # gave them, the age of the thread underneath, and for a while what they are
  # doing right now. Every one of those is a HEADLINE, and a column of headlines
  # with people's names attached is a feed read top-down for content.
  #
  # THE DOING WAS THE HARDEST TO GIVE UP and it went the same way, because the
  # objection to it was never that it was stale — it is the freshest thing on the
  # surface — but that it is a SENTENCE, and a sentence under every name is a
  # feed however new it is. It lives in the band, one person at a time, because
  # you chose them.
  #
  # THE MARKS ARE A DIFFERENT KIND OF THING. Two glyphs, no words: what the last
  # letter WAS on the left, which way it WENT on the right. Neither competes with
  # a name for reading, which is exactly why they are allowed to stay.
  test "a row says who, and what passed, and nothing in words", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    rows = html |> String.split(~s(class="scopes-item)) |> tl() |> Enum.join()

    # One word for a person, not two.
    refute rows =~ "scopes-name"

    # And nothing under it: not the age of the thread, not a round's number, and
    # not what they are up to.
    refute rows =~ "scopes-when"
    refute rows =~ "scopes-round"
    refute rows =~ "scopes-doing"
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

  # ONE PRESS, NOT TWO. It used to take a scroll and then a press: the column was
  # small rows and a BAND, and a band needs one of them nominated before it can
  # be pressed. An item the size of what it is about needs no nominating, so the
  # press that opens somebody is the only press there is.
  test "pressing a person opens their page", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    refute html =~ "id=\"panel\""
    refute has_element?(live, "#panel")

    opened = render_click(live, "open_item", %{"id" => second_held_id()})
    assert has_element?(live, "#scopes.is-open")
    assert has_element?(live, "#panel")
    assert opened =~ "DAD"
    assert opened =~ "MICHAEL"
    # The panel names its two views. LETTERS, not RECORD: "record" names the act
    # of capturing, which a typed letter never went through.
    assert opened =~ "LETTERS"
    assert opened =~ "LIVE"
    refute opened =~ "RECORD"

    render_click(live, "toggle_open")
    refute has_element?(live, "#panel")
  end

  test "the panel is named for what it is, in markup as well as on screen", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    # A thread with a text letter in it, so the third kind reaches the panel too.
    opened = render_click(live, "open_item", %{"id" => nth_held_id(4)})

    # "presence" named the medium, which made a written letter unnameable. The
    # ids, the classes and the hook say panel now, not just the heading.
    for id <- ~w(panel panel-letters panel-scroll panel-item panel-when),
        do: assert(opened =~ id)

    assert opened =~ ~s(phx-hook="Panel")
    refute opened =~ "presence-"
    refute opened =~ "PresencePanel"

    # The panel's own empty band is the same ellipsis the list's is.
    assert opened =~ "focus-dot"

    # THE FRAME IS HIDDEN BUT NOT REMOVED, and that is load-bearing rather than
    # incidental. app.css takes it out of sight when the panel opens — it
    # answers the band, and the band has become a header — but the ELEMENT has
    # to stay, because hiding a media element does not silence it and only
    # scopes.ts can tear the media down. Render it conditionally and a voice
    # goes on playing over an open panel from a box nobody can see or press.
  end

  test "losing the selection closes the panel with it", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    render_hook(live, "select", %{"index" => 0})
    render_click(live, "toggle_open")
    assert has_element?(live, "#panel")

    render_hook(live, "deselect", %{})
    refute has_element?(live, "#panel")
    refute has_element?(live, "#bar.is-picked")
  end

  test "the two boxes are the head of the list, and each flips one axis", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    # WHERE, and WHICH OF THEM. The place box names the place; the population box
    # names the population you are inside and carries its own count.
    assert tags_say(live) =~ "FINLAND"
    assert tags_say(live) =~ "#{held_count()} RELATIONSHIPS"

    # THE POPULATION BOX SWAPS, and never leaves the people. It shows where you
    # ARE rather than offering both — one box, not a segmented pair.
    live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert tags_say(live) =~ "#{stranger_count()} PEOPLE"
    # One box, so the population it swapped OUT of is not on screen at all. The
    # two words no longer share a stem, so this can refute the WORD outright —
    # it used to have to name the count as well, because "UNSCOPES" contains
    # "SCOPES" and the plain refute passed for the wrong reason.
    refute tags_say(live) =~ "RELATIONSHIPS"

    # THE PLACE BOX SWAPS WHAT THE LIST HOLDS. The roll opens unselected, so the
    # box reads WORLD — no country chosen — and the world's own totals with it.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert tags_say(live) =~ "WORLD"
    # EVERYWHERE IS THE SUM OF THE PLACES, and the whole cast lives in one, so
    # the world says exactly what Finland said.
    assert tags_say(live) =~ "#{stranger_count()} PEOPLE"
  end

  test "the box counts what the list under it holds", %{conn: conn} do
    # THE TWO USED TO BE UNRELATED — a hand-written table over an unfiltered
    # list, so Finland could claim 122 strangers above a list of five. The place
    # is the list's parent now, which makes them one question asked twice.
    {:ok, live, _html} = live(conn, ~p"/")
    assert tags_say(live) =~ "#{held_count()} RELATIONSHIPS"
    assert rows_in(render(live)) == held_count()

    unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert tags_say(live) =~ "#{stranger_count()} PEOPLE"
    assert rows_in(unscoped) == stranger_count()

    # And a place nobody is in says so, rather than borrowing the world's total.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    render_hook(live, "select", %{"index" => 1})
    empty = live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert tags_say(live) =~ "NIGERIA"
    assert tags_say(live) =~ "0 PEOPLE"
    assert rows_in(empty) == 0
  end

  test "the band moves the place box but commits nothing", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    live |> element(~s(button[phx-click="place_box"])) |> render_click()

    # A country scrolling through the band updates the box AND its counts, so
    # you can read a place's two populations without leaving the roll.
    render_hook(live, "select", %{"index" => 1})
    assert tags_say(live) =~ "NIGERIA"
    assert tags_say(live) =~ "0 RELATIONSHIPS"

    # Still in the world. The band alone commits nothing, and neither does the
    # band's own press.
    render_click(live, "toggle_open")

    # AND THE WAY OUT THAT CHANGES NOTHING leaves with what you came in with.
    render_hook(live, "cancel_place", %{})
    assert tags_say(live) =~ "FINLAND"
    assert tags_say(live) =~ "#{held_count()} RELATIONSHIPS"
  end

  test "either box is a door back, and both take the place with them", %{conn: conn} do
    # Somebody abroad, so the second place in this test is not an empty one.
    person("CARIOCA", "Brazil")
    {:ok, live, _html} = live(conn, ~p"/")

    # THE PLACE BOX commits what settled and keeps the population you had.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})
    scoped = live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert tags_say(live) =~ "BRAZIL"
    assert tags_say(live) =~ "0 RELATIONSHIPS"
    # You hold nobody in Brazil, so the list that came back is empty — and says
    # so rather than showing Finland's people under Brazil's name. Read from the
    # ROWS: the launcher's scoping room lists everyone you hold, everywhere, and
    # is not what this is about.
    assert rows_in(scoped) == 0
    refute has_element?(live, "#panel")

    # THE POPULATION BOX commits it too, and swaps population on the way — one
    # press answering both halves, which is what the two count boxes used to do.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})
    unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert tags_say(live) =~ "BRAZIL"
    assert tags_say(live) =~ "1 PEOPLE"
    # A stranger only Brazil holds, so the place really came with it.
    assert unscoped =~ "CARIOCA"
    refute unscoped =~ "AMINA"
  end

  # THE WAY OUT IS THE GESTURE THAT GOT YOU IN, and there is no longer a control
  # for it. A cancel X stood beside the place while these lived on a line above
  # the list, always in view; behind the band it would be hidden by the very swipe
  # somebody makes to leave. So the drawer IS the mode — the bar says whether it
  # is open, the hook opens it on arrival and cancels it on the way out, and the
  # server keeps `cancel_place` for the hook to call rather than for a button.
  test "the drawer being open is what says the roll of places is open", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")
    refute has_element?(live, ~s(button[phx-click="place_box"][aria-pressed="true"]))
    refute has_element?(live, ~s(button[phx-click="cancel_place"]))

    opened = live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert has_element?(live, ~s(button[phx-click="place_box"][aria-pressed="true"]))
    assert has_element?(live, ~s(button[phx-click="place_box"][aria-pressed="true"]))
    refute has_element?(live, ~s(button[phx-click="cancel_place"])), "the swipe out is the cancel"

    # WORLD is a choice like any other, so pressing the box on an empty band
    # commits it rather than being inert.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert tags_say(live) =~ "WORLD"
    assert tags_say(live) =~ "#{held_count()} RELATIONSHIPS"
    refute has_element?(live, ~s(button[phx-click="place_box"][aria-pressed="true"]))

    # And leaving without choosing is the same event, sent by the hook.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    render_hook(live, "cancel_place", %{})
    refute has_element?(live, ~s(button[phx-click="place_box"][aria-pressed="true"]))
  end

  test "only the place lights, and only while the world is open", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    # `(?<!:)` OR IT MATCHES THE HOVER. The place is set like a name now and takes
    # a name's ink at rest, with terracotta as its HOVER — so a bare search for
    # the colour finds `hover:text-primary-600` and reports every tag as lit.
    lit = ~r/(list-place|list-scope)[^"]*(?<!:)text-primary-600/
    tags = fn -> tags_html(live) end

    # NOTHING IS LIT OVER PEOPLE. Both tags were washed boxes and exactly one was
    # always on; as small tracked words at the head of the list, terracotta means
    # what it means everywhere else here — look at this — and neither of them is
    # asking anything of you while you are simply reading the list.
    assert Regex.scan(lit, tags.(), capture: :all_but_first) == []

    # OPENING THE WORLD IS A STATE WORTH SHOWING, and it is the only one either
    # tag has. The population is a toggle you can press from either side, and
    # neither side is more chosen than the other.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert Regex.scan(lit, tags.(), capture: :all_but_first) == [["list-place"]]

    # And it goes out again on the way back.
    live |> element(~s(button[phx-click="place_box"])) |> render_click()
    assert Regex.scan(lit, tags.(), capture: :all_but_first) == []
  end

  test "a place is one line, shouted, and its rows close up to suit", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")
    assert html =~ "scopes-item"

    places = live |> element(~s(button[phx-click="place_box"])) |> render_click()

    # UPPERCASE like every other word on this surface. The fixtures store
    # "Finland" because that is the country's name; the list is a list.
    assert places =~ "NIGERIA"
    refute places =~ ">\n                  Nigeria"

    # And a shorter row, because a place has no age hung under it. At the
    # people row's height the words sat further apart than the band is tall.
    assert places =~ "scopes-item"
    refute places =~ "h-(--row-h)"
  end

  test "the act opens the launcher; the launcher's own master closes it",
       %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # ONE MEANING EACH. The act used to be plus, cross and back — three answers
    # from a button at the foot of the page, which put the way out of a form a
    # screen below the form. It opens, and nothing else.
    assert html =~ ~s(id="act")
    assert html =~ "act-mark"
    refute html =~ "act-back"
    assert html =~ ~s(aria-expanded="false")

    # AND EVERY ROOM CARRIES THE WAY OUT, in the row with its own buttons. A
    # room you can enter and not leave is the bug this catches.
    rooms = Regex.scan(~r/data-room="([a-z]+)"/, html, capture: :all_but_first) |> List.flatten()
    assert length(rooms) > 1

    for room <- rooms do
      body = Regex.run(~r/data-room="#{room}".*?(?=data-room="|\z)/s, html) |> List.first()
      assert body =~ "data-launcher-back", "the #{room} room has no way back"
    end
  end

  test "the launcher is one overlay with a room per door", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # THE REGISTRY: a body per room, a cell per door, joined by name alone. If
    # a door ever names a room that does not exist, this is what catches it.
    doors =
      Regex.scan(~r/data-open-room="([a-z]+)"/, html, capture: :all_but_first) |> List.flatten()

    rooms =
      Regex.scan(~r/data-room="([a-z]+)"/, html, capture: :all_but_first) |> List.flatten()

    assert "launcher" in rooms
    assert doors != []
    assert Enum.all?(doors, &(&1 in rooms)), "a launcher cell opens a room that is not there"

    # It is OPAQUE. The panel it came from floated on a 90% wash because the
    # thing behind it was a map you read through; here it is a list of names.
    assert html =~ "launcher-ground absolute inset-0 bg-light-50 dark:bg-dark-950"
    refute html =~ "bg-white/90"
  end

  test "the launcher says whether you are checked in", %{conn: conn, me: me} do
    # Checked in, the launcher greets you by name.
    {:ok, _live, html} = live(conn, ~p"/")
    assert html =~ String.upcase(me.name)
    refute html =~ "NOT CHECKED IN"

    {:ok, _live, html} = live(build_conn(), ~p"/")
    assert html =~ "NOT CHECKED IN"

    # THE CELL IS ALWAYS "PASSPORT". It leads to a room holding BOTH doors —
    # request one, or check in with one you have — so naming it after either
    # half would be a door lying about where it goes.
    assert html =~ "PASSPORT"
    refute html =~ ">\n    Check in\n  <"
  end

  test "a visitor holds nobody, and opens on the list that has people in it",
       %{conn: _conn} do
    {:ok, _live, html} = live(build_conn(), ~p"/")

    # SCOPED is the list's subject and the right default for anyone who holds
    # people — but for a visitor it is empty, and opening on an empty list makes
    # an app look broken when it is merely new. So the strangers lead.
    assert html =~ "PEOPLE"
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
  # WHERE THE LIST'S OWN TWO FACTS ARE NOW. They were the first two of the three
  # boxes on the right rail and read out of `.scope-boxes`; they are a caption at
  # the head of the list, because a place and a population are true of the LIST
  # and the rail is for the things that answer the BAND.
  # TWO DRAWERS, ONE READING. The list's settings used to share a line and now
  # share a track — one page for WHERE and one for WHO — so anything asking what
  # the head of the list says has to ask both.
  # THE OLD SETTLE SPOKE IN INDEXES because the band was a position in a column.
  # A press names WHO, so the tests do too.
  defp held_ids do
    Peoplemedia.Relationships.held_by(
      Peoplemedia.Repo.get_by!(Peoplemedia.People.Person, name: "ojo").id
    )
    |> Enum.map(fn {_scope, person} -> person.id end)
  end

  defp nth_held_id(n), do: held_ids() |> Enum.at(n)
  defp second_held_id, do: nth_held_id(1)

  defp tags_html(live) do
    render(live)
    |> String.split(~s(class="list-tags))
    |> tl()
    |> Enum.map_join(" ", &(&1 |> String.split("</div>") |> hd()))
  end

  defp tags_say(live) do
    live
    |> tags_html()
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp boxes_html(live), do: live |> element(".scope-boxes") |> render()

  # How many people the list is actually showing. `scopes-item` is the row and
  # nothing else wears it, so counting them is counting the list.
  defp rows_in(html), do: html |> String.split(~s(class="scopes-item)) |> length() |> Kernel.-(1)
end
