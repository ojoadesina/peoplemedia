defmodule PeoplemediaWeb.IndexLiveTest do
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  test "the surface renders its line and every scoped person", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    assert html =~ "SO YOU DON&#39;T DO LIFE ALONE"
    # the label leads, their own name follows it
    assert html =~ "MUM"
    assert html =~ "SARAH"
    # one row per person, and a band for them to pass through
    assert html |> String.split(~s(class="scopes-item)) |> length() == 20
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
    live |> element(~s(button[phx-click="to_location"])) |> render_click()
    # A count is only a door once a place is standing in the band.
    render_hook(live, "select", %{"index" => 2})
    unscoped = live |> element(~s(button[phx-value-scope="UNSCOPED"])) |> render_click()

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

  test "every person carries the frame its row hands to the screen", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    for mode <- ~w(empty voice face), do: assert(html =~ ~s(data-frame="#{mode}"))
    for state <- ~w(absent present live), do: assert(html =~ ~s(data-state="#{state}"))

    # An open line with nothing coming through it — the case that justifies
    # `live` existing as a state at all.
    assert html =~ ~r/data-state="live" data-frame="empty"/
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

  test "the head of the list is the place its rows came out of", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    # A HIERARCHY, NOT A COMPOUND TERM. "Scoped Finland" is not a thing — it is
    # a filter said as though it were one. Finland is a place, and the list is
    # one of the two populations that place holds, so the place is the heading
    # and what came out of it is the caption. Two nodes, so this reads the TEXT.
    assert tag_says(live) =~ "FINLAND 19 SCOPES"
    assert live |> element(".scope-tags") |> render() |> String.split("<button") |> length() == 2

    # The count is the list's own length, not a fact stored beside it.
    assert html |> String.split(~s(class="scopes-item)) |> length() == 20

    opened = live |> element(~s(button[phx-click="to_location"])) |> render_click()
    assert has_element?(live, ~s(button[phx-click="to_location"][aria-pressed="true"]))
    assert opened =~ "Nigeria"

    # A roll of countries had to come out of something too, and there is only
    # one thing left for it to have come out of.
    assert tag_says(live) =~ "WORLD 18 PLACES"
    refute tag_says(live) =~ "FINLAND"
  end

  test "the lens says which population it holds, in the mark's column", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    # SCOPED is two rings INTERSECTED — each one's edge falls inside the other,
    # so neither can be lifted away on its own.
    assert html =~ ~s(<rect x="3.5" y="7" width="10" height="10">)
    assert html =~ ~s(<rect x="10.5" y="7" width="10" height="10">)

    live |> element(~s(button[phx-click="to_location"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})

    # UNSCOPED is the same two rings in the same place — still intersected, so
    # it cannot read as "these two have nothing to do with each other" — but
    # each with a gap cut out of its top, so neither one closes.
    unscoped = live |> element(~s(button[phx-value-scope="UNSCOPED"])) |> render_click()
    assert unscoped =~ "M7 7H3.5v10h10V7h-3.5"
    assert unscoped =~ "M14 7h-3.5v10h10V7h-3.5"
    refute unscoped =~ ~s(<rect x="3.5" y="7")
  end

  test "an unread mark keeps its full voice; the rest are held quiet", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/")

    # is-lit rides only on a mark whose row has an unopened letter, and it is
    # what app.css exempts from the resting opacity. Dimming those too was the
    # mistake in between: it flattened the one difference the marks are for.
    lit = ~r/letter-glyph[^"]*is-lit[^"]*text-primary-600/
    assert Regex.scan(lit, html) |> length() == 6

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

  test "a place answers with two counts, and each is a door into its people", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    live |> element(~s(button[phx-click="to_location"])) |> render_click()

    # Nigeria settles in the band: both populations appear, as two numbers
    # rather than one total waiting to be split.
    counts = render_hook(live, "select", %{"index" => 1})
    assert counts =~ "41"
    assert counts =~ "SCOPES"
    assert counts =~ "4169"
    assert counts =~ "UNSCOPES"

    # The band alone commits nothing here — it cannot say WHICH population, so
    # the head of the list is still the world rather than the country under it.
    live |> element(".focus-box") |> render_click()
    refute tag_says(live) =~ "NIGERIA"

    # Pressing a count answers both halves at once: the place and the people.
    scoped = live |> element(~s(button[phx-value-scope="SCOPED"])) |> render_click()
    assert tag_says(live) =~ "NIGERIA 19 SCOPES"
    assert scoped =~ "MUM"
    refute has_element?(live, "#panel")
  end

  test "the unscoped count opens the strangers of that place", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    live |> element(~s(button[phx-click="to_location"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})

    unscoped = live |> element(~s(button[phx-value-scope="UNSCOPED"])) |> render_click()
    assert tag_says(live) =~ "BRAZIL 15 UNSCOPES"
    # A stranger only the unscoped world holds, so the list really swapped.
    assert unscoped =~ "AMINA"
  end

  # WHAT THE TAG SAYS, with the markup taken out of the way. It is a two-line
  # button — the scope over the place as faded subtext — so the two halves are
  # in separate elements and no substring of the raw HTML holds both. Stripping
  # the tags and collapsing the whitespace asks the question the tests actually
  # mean: does this control, read aloud, name a scope and a place together.
  defp tag_says(live) do
    live
    |> element(".scope-tags")
    |> render()
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
