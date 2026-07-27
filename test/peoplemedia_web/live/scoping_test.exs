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

  # The word on the uncovered action, with the markup taken out of the way —
  # asserting on rendered indentation is asserting on the formatter.
  defp act_of(row) do
    row
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.split()
    |> List.last()
  end

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
      assert Enum.all?(rows, &(act_of(&1) == "SCOPE"))
      assert Enum.all?(rows, &(&1 =~ ~s(data-panel-open="scope")))

      # SOMEONE YOU HOLD CAN BE WRITTEN TO — and cannot be scoped again, which
      # is why the action swaps rather than doubling.
      {:ok, _live, scoped} = live(conn, ~p"/")
      rows = Regex.scan(~r/<li [^>]*class="scopes-item.*?<\/li>/s, scoped) |> List.flatten()
      assert rows != []
      assert Enum.all?(rows, &(act_of(&1) == "WRITE"))
      assert Enum.all?(rows, &(&1 =~ ~s(data-panel-open="write")))
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
      assert row =~ ~s(data-panel-open="scope")
    end
  end

  describe "scoping someone" do
    test "names them, asks, and tells them", %{conn: conn, me: me} do
      them = person("NEWCOMER", "Brazil")

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
      them = person("NEWCOMER", "Brazil")
      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert render_submit(live, :scope_send, %{"label" => "   "}) =~ "WHAT DO YOU CALL THEM?"
      assert Relationships.pending_scopes_for(me.id) == %{incoming: [], outgoing: []}
    end

    test "a visitor cannot scope anyone", %{} do
      them = person("NEWCOMER", "Brazil")
      {:ok, live, _} = live(build_conn(), ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "scope"})

      assert render_submit(live, :scope_send, %{"label" => "cousin"}) =~ "CHECK IN FIRST"
    end
  end

  describe "the scoping room" do
    test "says nothing is in motion when nothing is", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/")
      assert html =~ "NOTHING IN MOTION"
    end

    test "shows both directions, and whose move it is", %{conn: conn, me: me} do
      # One I asked for, and one asked of me.
      mine = person("OUTBOUND", "Brazil")
      theirs = person("INBOUND", "Brazil")
      {:ok, _} = Relationships.request_scope(me.id, mine.id, "COUSIN")
      {:ok, _} = Relationships.request_scope(theirs.id, me.id, "FRIEND")

      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "INCOMING · 1"
      assert html =~ "OUTGOING · 1"
      assert html =~ "INBOUND"
      assert html =~ "calls you “FRIEND” — answer"
      assert html =~ "OUTBOUND"
      assert html =~ "you call them “COUSIN” · waiting"
      refute html =~ "NOTHING IN MOTION"
    end
  end
end
