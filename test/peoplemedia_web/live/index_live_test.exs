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

  # TWO MARKS, AND THEY ANSWER DIFFERENT QUESTIONS. On the left, whether they are
  # ROUND — a fact about them, which everybody has an answer to at every moment.
  # On the right, which way the last letter went — a fact about the two of you.
  #
  # THE LEFT ONE USED TO BE A LETTER'S KIND TOO, and that is what made it useless:
  # a correspondence is something only the two of you have, so a visitor's list
  # could not carry a single mark, the PEOPLE tab could not either, and even a
  # busy thread went blank the moment nothing was new. A column that is empty for
  # most rows most of the time is not a column.
  test "an item carries a head, a word block, and no words of its own", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")
    rows = html |> String.split(~s(class="scopes-item)) |> tl() |> Enum.join()

    assert rows =~ "frame"
    refute rows =~ "tabular-nums"
    refute rows =~ "scopes-name"
    refute rows =~ "scopes-when"

    # THE PLATE SAYS WHAT THE MARK USED TO. A mark that named what a frame held
    # was a caption on a picture; the frame shows what it holds, and the plate
    # says what they are round with in their own words.
    assert rows =~ "word"

    # STRANGERS GET ONE TOO, and that is the whole point of moving it off the
    # letters: they have no correspondence at all and they are still either round
    # or not.
    # THE FLOW IS ABOUT WORDS NOW, so it is drawn on the block that holds them and
    # only where a round has any. A stranger with no round has neither.
    unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert unscoped =~ "frame"
    assert unscoped =~ "word", "no correspondence, so no direction to show"
  end

  # NEVER LIT. Terracotta is spent on the one thing asking something of you, and
  # being round is an invitation rather than a demand — Law 1 says absence is
  # silent, and its opposite is not a summons either.
  test "and the round mark never takes the attention colour", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")
    rows = html |> String.split(~s(class="scopes-item)) |> tl() |> Enum.join()

    for glyph <- rows |> String.split(~s(class="letter-glyph)) |> tl() do
      refute glyph |> String.split("</span>") |> hd() =~ "is-lit"
    end
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

  test "the letter box holds the last letter they sent, and nothing when there is none",
       %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    # THE ROW CARRIES THE BOX AS DATA and always has — the hook reads these on
    # settle. What is in it is the newest INCOMING letter's kind, because the
    # box is the one thing on this surface that answers you; a box holding the
    # thread's newest entry would as often hold your own letter back at you.
    #
    # The cast is written so this cannot pass by accident: two of the six
    # threads end on a letter of THEIRS that is not text.
    kinds =
      Regex.scan(~r/data-letter-kind="(\w+)"/, html, capture: :all_but_first) |> List.flatten()

    assert "voice" in kinds
    assert "face" in kinds

    # A THREAD THAT ONLY EVER WENT ONE WAY HAS NOTHING TO SHOW, and neither does
    # a person you do not hold — a letter is written to a scope, so a stranger's
    # thread is not empty, it does not exist. Both arrive as "empty", and the
    # hook draws nothing for it.
    assert "empty" in kinds

    unscoped = live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    strangers = Regex.scan(~r/data-letter-kind="(\w+)"/, unscoped, capture: :all_but_first)
    assert Enum.all?(List.flatten(strangers), &(&1 == "empty"))

    # PRESENCE IS READ OFF A REAL AROUND NOW, and both answers are in the cast —
    # `present` used to be hardcoded for everybody, so this assertion passed on a
    # placeholder and could never have caught it going wrong.
    assert html =~ ~s(data-state="present")
    assert html =~ ~s(data-state="absent")
    # AND `live` IS NOT AROUND'S TO SET. It means a face or a voice actually
    # running, which is one thing somebody might be doing inside an around
    # rather than what being around is.
    refute html =~ ~s(data-state="live")
  end

  test "the row hands the box the words, and the hook reads the name it is given",
       %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # THE WORDS TRAVEL WITH THE KIND. A text letter is the only kind anyone can
    # write yet, so a box that could only hold the two that play was a box for
    # recordings.
    assert html =~ ~s(data-body="hello")

    # AND THE HOOK MUST READ THE ATTRIBUTE THAT IS ACTUALLY THERE. This is not
    # paranoia about a typo — renaming the frame to the letter box rewrote
    # `dataset.frame` into `dataset.letterbox` while the markup kept
    # `data-letter-kind`, so the box showed nothing at all for a whole release
    # and every server-side assertion above still passed. A string that crosses
    # from Elixir to TypeScript has to be checked on both sides or neither.
    hook = File.read!("assets/js/hooks/scopes.ts")
    assert hook =~ "dataset.letterKind", "the hook reads a data attribute the row does not carry"
    assert hook =~ "dataset.body"
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
    assert opened =~ "focus-dot"
    assert opened =~ "rotate(-45 12 12)"

    # THE FRAME IS HIDDEN BUT NOT REMOVED, and that is load-bearing rather than
    # incidental. app.css takes it out of sight when the panel opens — it
    # answers the band, and the band has become a header — but the ELEMENT has
    # to stay, because hiding a media element does not silence it and only
    # scopes.ts can tear the media down. Render it conditionally and a voice
    # goes on playing over an open panel from a box nobody can see or press.
    assert opened =~ ~s(id="letterbox")
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

  # THE COUNT IS THE WHOLE OF WHAT THIS LINE SAYS NOW. It counted people in a
  # PLACE once, and the place is gone — the list is simply everybody, so the
  # number is everybody, and pressing it flips which everybody you mean.
  test "the count says how many are in the list under it", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    assert tags_say(live) =~ "#{held_count()} RELATIONSHIPS"

    live |> element(~s(button[phx-click="scope_box"])) |> render_click()
    assert tags_say(live) =~ "PEOPLE"
    refute tags_say(live) =~ "RELATIONSHIPS"
  end

  test "the empty band says nothing yet, and does not say it with the mark", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # AN ELLIPSIS, NOT "--". The app's mark is a pair of dashes and the voice
    # glyph is one bar, so two dashes in terracotta at the head of the list read
    # as the logo turning up in the middle of the page.
    #
    # THREE ELEMENTS RATHER THAN THREE CHARACTERS — first so they can run in turn
    # when the list is live, and then because a typed period is whatever size the
    # font says it is: about four pixels of ink at the band's own type, which is
    # too small to be a signal even while it is moving. A drawn dot takes the size
    # it is given.
    assert html =~ "focus-empty"

    dots = html |> String.split(~s(class="focus-empty)) |> tl() |> hd()
    assert length(String.split(dots, "focus-dot")) - 1 == 3
    refute html |> String.replace(~r/<[^>]*>/, " ") =~ ~r/(?<!\.)--(?!-)/
  end

  # WHETHER THE LIST MOVES IS SHOWN ON THE BAND, and nowhere else. It was the
  # word LIVE beside the word PAUSED — same length, same weight, same place, so
  # you had to read the letters to know which state you were in — then a lamp in
  # the settings, and now not a control at all: pausing is held back, the list is
  # always live, and the three dots in the band report it where you are already
  # looking rather than where you would have gone to change it.
  test "live is on the band's own mark, not in a word", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    refute html =~ "live-lamp"
    refute tags_say(live) =~ "PAUSED"
    refute tags_say(live) =~ "LIVE"
    refute has_element?(live, ~s(button[phx-click="toggle_live"]))

    assert has_element?(live, ~s(#bar.is-live))
    assert html =~ "focus-dot"
  end

  test "the rail answers the band, and the head of the list answers the list", %{conn: conn} do
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

    # THE SPLIT IS THE POINT. The cluster's own comment used to claim all three
    # boxes "answered the band" while two of them answered the LIST — the same
    # whichever name had scrolled in. Those two are a caption at the head now,
    # and what is left on the rail genuinely is about the person under the band.
    assert boxes =~ ~s(id="letterbox")
    refute boxes =~ "list-scope"

    tags = tags_html(live)
    assert tags =~ "list-scope"
    refute tags =~ "letterbox"
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
