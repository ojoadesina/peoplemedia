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

    refute html =~ "id=\"presence-panel\""
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
    assert has_element?(live, "#presence-panel")
    assert opened =~ "DAD"
    assert opened =~ "MICHAEL"
    # The panel names its two views.
    assert opened =~ "RECORD"
    assert opened =~ "LIVE"

    live |> element(".focus-box") |> render_click()
    refute has_element?(live, "#presence-panel")
  end

  test "losing the selection closes the panel with it", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")

    render_hook(live, "select", %{"index" => 0})
    live |> element(".focus-box") |> render_click()
    assert has_element?(live, "#presence-panel")

    render_hook(live, "deselect", %{})
    refute has_element?(live, "#presence-panel")
    refute has_element?(live, "#bar.is-picked")
  end

  test "the tag is one sentence, and it opens the world", %{conn: conn} do
    {:ok, live, html} = live(conn, ~p"/")

    # A scope and a place said together, on ONE button — not two switches.
    assert html =~ "SCOPED FINLAND"
    assert live |> element(".scope-tags") |> render() |> String.split("<button") |> length() == 2

    opened = live |> element(~s(button[phx-click="to_location"])) |> render_click()
    assert has_element?(live, ~s(button[phx-click="to_location"][aria-pressed="true"]))
    assert opened =~ "Nigeria"
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
    refute render(live) =~ "SCOPED NIGERIA"

    # Pressing a count answers both halves at once: the place and the people.
    scoped = live |> element(~s(button[phx-value-scope="SCOPED"])) |> render_click()
    assert scoped =~ "SCOPED NIGERIA"
    assert scoped =~ "MUM"
    refute has_element?(live, "#presence-panel")
  end

  test "the unscoped count opens the strangers of that place", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/")
    live |> element(~s(button[phx-click="to_location"])) |> render_click()
    render_hook(live, "select", %{"index" => 2})

    unscoped = live |> element(~s(button[phx-value-scope="UNSCOPED"])) |> render_click()
    assert unscoped =~ "UNSCOPED BRAZIL"
    # A stranger only the unscoped world holds, so the list really swapped.
    assert unscoped =~ "AMINA"
  end
end
