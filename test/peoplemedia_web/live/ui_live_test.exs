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

  # THE PANEL HOLDS THE CAPTURE; IT IS NOT THE CAPTURE.
  #
  # It was tried the other way — the picture filling the block edge to edge with
  # the name laid over it under a gradient — and that is a poster, not a person
  # in a list. The gradient was the tell: a scrim exists to keep words legible
  # over an image, which is a problem you only have because you put the words on
  # the image. So there is no scrim anywhere, and the head keeps its own line.
  test "the panel holds the capture rather than being it", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    refute html =~ "frame-scrim", "nothing is drawn over anything, so nothing needs fading"

    filled = Enum.find(frames(html), &(&1 =~ ~s(data-kind="still")))
    assert filled, "no filled frame in the exhibit"

    # The head comes first and the capture after it — a drawer, not a backdrop.
    [_head, body] = String.split(filled, "frame-body", parts: 2)
    assert body =~ "frame-media"
    assert filled |> String.split("frame-body") |> hd() =~ "frame-name"

    # CLOSED, THEY ARE ALL THE SAME SHAPE. The head is the whole of a closed
    # frame, and its height is stated in one place for every one of them.
    for f <- frames(html), do: assert(f =~ "frame-head")
  end

  # AND AN EMPTY FRAME HAS NO DRAWER AT ALL, not an empty one. A body that opened
  # onto nothing would be a panel that answers a press with a blank rectangle.
  test "an empty frame has nothing to open", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    empty = Enum.find(frames(html), &(&1 =~ ~s(data-kind="empty")))
    refute empty =~ "frame-body"
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

  # A VOICE HAS NO PICTURE, so the line at the panel's foot is the only thing it
  # can show — and a still, which has no duration, has nothing to report.
  test "only what plays carries a progress line", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/ui")

    for f <- frames(html) do
      kind = Regex.run(~r/data-kind="(\w+)"/, f, capture: :all_but_first) |> hd()

      if kind in ~w(face voice),
        do: assert(f =~ "frame-progress", "#{kind} plays, so it can say how far"),
        else: refute(f =~ "frame-progress", "#{kind} has no duration to report")
    end
  end

  test "a visitor gets the exhibit too", %{conn: _conn} do
    {:ok, _live, html} = live(build_conn(), ~p"/ui")
    assert length(frames(html)) > 1
  end
end
