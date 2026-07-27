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

  test "the tag is one sentence, and it opens the world", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    # A scope and a place said together, on ONE button — not two switches. The
    # tag is a COUNT over that sentence now, the shape a headline number takes,
    # so the two are separate nodes and `html =~ "SCOPED FINLAND"` cannot see
    # them. What the test is about has not changed, so it reads the tag's TEXT.
    assert tag_says(live) =~ "SCOPED FINLAND"
    assert live |> element(".scope-tags") |> render() |> String.split("<button") |> length() == 2

    # THE HEAD OF A LIST COUNTS THE LIST. Nineteen scoped people, nineteen rows.
    assert tag_says(live) =~ "19"
    assert html |> String.split(~s(class="scopes-item)) |> length() == 20

    opened = live |> element(~s(button[phx-click="to_location"])) |> render_click()
    assert has_element?(live, ~s(button[phx-click="to_location"][aria-pressed="true"]))
    assert opened =~ "Nigeria"

    # Over places the caption follows the LIST, not the lens it came from —
    # a tally of the world under the name of one country is the one pairing
    # this can get wrong.
    assert tag_says(live) =~ "18 PLACES"
    refute tag_says(live) =~ "FINLAND"
  end

  test "the lens says which population it holds, in the mark's column", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    # SCOPED is two square links overlapping — a hold.
    assert html =~ ~s(<rect x="2.5" y="8" width="10" height="8">)
    assert html =~ ~s(<rect x="11.5" y="8" width="10" height="8">)

    live |> element(~s(button[phx-click="to_location"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})

    # UNSCOPED is the same two links broken open and drawn apart.
    unscoped = live |> element(~s(button[phx-value-scope="UNSCOPED"])) |> render_click()
    assert unscoped =~ "M10 8H2.5v8H10"
    assert unscoped =~ "M14 8h7.5v8H14"
    refute unscoped =~ ~s(<rect x="2.5" y="8")
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

    # The band alone commits nothing here — it cannot say WHICH population.
    live |> element(".focus-box") |> render_click()
    refute tag_says(live) =~ "SCOPED NIGERIA"

    # Pressing a count answers both halves at once: the place and the people.
    scoped = live |> element(~s(button[phx-value-scope="SCOPED"])) |> render_click()
    assert tag_says(live) =~ "SCOPED NIGERIA"
    assert scoped =~ "MUM"
    refute has_element?(live, "#panel")
  end

  test "the unscoped count opens the strangers of that place", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    live |> element(~s(button[phx-click="to_location"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})

    unscoped = live |> element(~s(button[phx-value-scope="UNSCOPED"])) |> render_click()
    assert tag_says(live) =~ "UNSCOPED BRAZIL"
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
