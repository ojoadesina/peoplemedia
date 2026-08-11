defmodule PeoplemediaWeb.HandshakeTest do
  @moduledoc """
  The three rounds of the handshake, driven from the surface. Until these
  answers existed the scoping room could show you a request and not let you
  answer it — a notice, not a handshake.
  """
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Peoplemedia.{Notifications, Relationships}

  setup %{conn: conn} do
    me = cast()
    %{conn: check_in(conn, me), me: me}
  end

  describe "answering" do
    test "scope back, then they accept, and only then are you held",
         %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, live, _} = live(conn, ~p"/")
      assert render(live) =~ "CALLS YOU “FRIEND” — ANSWER"

      # ROUND TWO is not merely a yes: it is where I say what I call them, and
      # that claim is theirs to see before it stands.
      render_submit(live, :scope_back, %{"other_id" => them.id, "label" => "neighbour"})

      refute Relationships.related?(me.id, them.id)
      %{outgoing: [out]} = Relationships.pending_scopes_for(me.id)
      assert out.phase == "waiting_accept"
      assert out.my_label == "NEIGHBOUR"

      # ROUND THREE is theirs, and it seals it.
      {:ok, _} = Relationships.accept(them.id, me.id)
      assert Relationships.related?(me.id, them.id)
    end

    test "the initiator finalises what came back", %{conn: conn, me: me} do
      them = person("OUTBOUND")
      {:ok, _} = Relationships.request_scope(me.id, them.id, "COUSIN")
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")

      {:ok, live, _} = live(conn, ~p"/")
      assert render(live) =~ "SCOPED YOU BACK “OJO” — FINALISE"

      render_click(live, :scope_accept, %{"id" => them.id})

      assert Relationships.related?(me.id, them.id)
      assert Relationships.pending_scopes_for(me.id) == %{incoming: [], outgoing: []}
      # And they now appear in the list as somebody held.
      assert render(live) =~ "COUSIN"
    end

    test "an answer with no name is refused — the name IS round two",
         %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, live, _} = live(conn, ~p"/")

      assert render_submit(live, :scope_back, %{"other_id" => them.id, "label" => " "}) =~
               "WHAT DO YOU CALL THEM?"

      %{incoming: [still]} = Relationships.pending_scopes_for(me.id)
      assert still.phase == "respond"
    end

    test "declining deletes nothing and can be re-asked", %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :scope_reject, %{"id" => them.id})

      refute Relationships.related?(me.id, them.id)
      assert Relationships.pending_scopes_for(me.id) == %{incoming: [], outgoing: []}

      # THE TIE STAYS TRACKED. Asking again reopens the same row rather than
      # writing a second one, which is what keeps "have we ever spoken?"
      # answerable.
      assert {:ok, :sent} = Relationships.request_scope(them.id, me.id, "FRIEND")
    end

    test "each round tells the other side", %{conn: conn, me: me} do
      them = person("INBOUND")
      {:ok, _} = Relationships.request_scope(them.id, me.id, "FRIEND")

      {:ok, live, _} = live(conn, ~p"/")
      render_submit(live, :scope_back, %{"other_id" => them.id, "label" => "neighbour"})

      assert Notifications.unread_count(them.id) == 1
    end
  end
end
