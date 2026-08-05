defmodule PeoplemediaWeb.UiLiveTest do
  @moduledoc """
  The frame, while it is being settled at `/ui`.

  AN EXHIBIT GETS THE TESTS ITS CLAIMS DESERVE and no more. Nothing here guards
  how it LOOKS — that is what the route is for, and a test that pinned the
  proportions would have to be rewritten every time somebody looked at it and
  moved something. What is guarded is the handful of statements the design makes
  that could quietly stop being true: four states rather than three, a picture
  that is the block rather than a thumbnail on it, and an empty frame that does
  not pretend it opens.
  """
  use PeoplemediaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Peoplemedia.Fixtures

  setup %{conn: conn} do
    me = cast()
    %{conn: check_in(conn, me), me: me}
  end

  # SPLIT ON THE ID, NOT THE CLASS. Splitting on `class="frame ` hands back the
  # text AFTER each class attribute, so every chunk is the tail of one frame with
  # the head of the next stuck to it — and a `data-kind` found in such a chunk
  # belongs to the frame after the one whose body you are reading.
  defp frames(html), do: html |> String.split(~s(<div id="frame-)) |> tl()

  defp kinds(html) do
    Regex.scan(~r/data-kind="(\w+)"/, html, capture: :all_but_first)
    |> List.flatten()
    |> Enum.frequencies()
  end

  test "every person is one block, and the page is what scrolls", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    assert length(frames(html)) > 1

    # THE LIST STOPS BEING A LIST. No band across the page, no scroller inside it,
    # nothing to settle a row into — those are the three things this route exists
    # to do without, so their absence is the claim worth holding on to.
    refute html =~ "scopes-scroll"
    refute html =~ ~s(id="bar")
    refute html =~ "scopes-item"
  end

  test "four states, and the mark says which", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")
    seen = kinds(html)

    assert Map.has_key?(seen, "empty"), "the resting state, and the commonest one"
    assert Enum.any?(~w(face voice still), &Map.has_key?(seen, &1)), "and at least one filled"

    # ONE RECTANGLE AT FOUR ANGLES, the same vocabulary the rows speak — so an
    # empty frame wears the mark a row wears for somebody who is not round.
    assert html =~ "letter-glyph"
    assert html =~ "rotate(-90 12 12)"
  end

  test "the picture is the block, not a thumbnail on it", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    filled =
      frames(html)
      |> Enum.find(&(&1 =~ ~s(data-kind="still") or &1 =~ ~s(data-kind="face")))

    assert filled, "no filled frame in the exhibit"
    assert filled =~ "frame-media"

    # AND THE NAME STAYS READABLE OVER IT. A scrim only where there is something
    # to darken: over the flat wash of an empty frame it would be a smudge with
    # no cause.
    assert filled =~ "frame-scrim"
    empty = Enum.find(frames(html), &(&1 =~ ~s(data-kind="empty")))
    refute empty =~ "frame-scrim"
    refute empty =~ "frame-media"
  end

  # AN EMPTY FRAME DOES NOT OPEN, and it does not offer to. There is nothing
  # behind it, so it takes no press, answers no key and shows no pointer — the
  # alternative is a block that invites a press and then does nothing, which is
  # worse than one that never asked.
  test "an empty frame does not pretend it opens", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    empty = Enum.find(frames(html), &(&1 =~ ~s(data-kind="empty")))
    head = empty |> String.split(">") |> hd()

    refute head =~ ~s(role="button")
    refute head =~ "tabindex"
    refute head =~ "cursor-pointer"
    assert empty =~ "nothing captured"
  end

  # WHICH FRAME IS OPEN IS THE CLIENT'S ANSWER — it depends on what somebody
  # pressed a moment ago — so the server renders every one of them closed and
  # exempts the class it cannot speak for. Without the exemption the first patch
  # to arrive would shut whatever was playing.
  test "the open state is the browser's, and the server says so", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    refute html =~ "is-open"
    assert html =~ ~s(phx-hook="Frame")
    assert html =~ "ignore_attrs"
  end

  test "a visitor gets the exhibit too", %{conn: _conn} do
    {:ok, _live, html} = live(build_conn(), ~p"/ui")
    assert length(frames(html)) > 1
  end
end
