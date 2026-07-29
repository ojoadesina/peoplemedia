defmodule PeoplemediaWeb.HandshakeTest do
  @moduledoc """
  The three rounds, driven from the surface, and the letters that become
  possible once they are done. Until these answers existed the scoping room
  could show you a request and not let you answer it — a notice, not a
  handshake.
  """
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Peoplemedia.{Letters, Notifications, Relationships}

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

  describe "writing" do
    test "a letter lands on the thread and lights their row", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)

      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "write"})
      render_submit(live, :write_letter, %{"body" => "are you well"})

      [newest | _] = Letters.thread(me.id, them.id)
      assert newest.body == "are you well"
      assert newest.from == "you"
      refute newest.read

      # From THEIR side the same row reads the other way round.
      [theirs | _] = Letters.thread(them.id, me.id)
      assert theirs.from == "them"
      assert Notifications.unread_count(them.id) >= 1
    end

    test "an empty letter is not a letter", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      before = length(Letters.thread(me.id, them.id))

      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "write"})

      assert render_submit(live, :write_letter, %{"body" => "  "}) =~ "SAY SOMETHING"
      assert length(Letters.thread(me.id, them.id)) == before
    end

    test "a letter opens the tie it needs, and grants nothing by doing so",
         %{conn: conn, me: me} do
      them = person("STRANGER")

      # THIS USED TO BE REFUSED, on the reasoning that being able to write is
      # the point of scoping. That is a rule about PERMISSION — who may write to
      # whom — and this app has not decided it; refusing decided it by accident,
      # and decided it "never".
      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "write"})
      render_submit(live, :write_letter, %{"body" => "hello"})

      assert [%{body: "hello", from: "you"}] = Letters.thread(me.id, them.id)

      # AND THEY ARE STILL A STRANGER. The row a letter makes says two people
      # have a correspondence; being scoped wants a settled state and two agreed
      # scopes, and this has neither.
      refute Relationships.related?(me.id, them.id)
      assert Enum.any?(Relationships.not_held_by(me.id), &(&1.id == them.id))
    end

    test "opening a thread IS reading it", %{conn: conn, me: me} do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, _} = Letters.write(them.id, me.id, %{kind: "text", body: "knock knock"})

      assert Enum.any?(Letters.thread(me.id, them.id), &(&1.from == "them" and not &1.read))

      {:ok, live, _} = live(conn, ~p"/")
      render_click(live, :pick_person, %{"id" => them.id, "act" => "write"})

      # Asking for a second press to admit you read something is asking you to
      # do the app's bookkeeping.
      refute Enum.any?(Letters.thread(me.id, them.id), &(&1.from == "them" and not &1.read))

      # AND MINE ARE UNTOUCHED. Reading is something the RECIPIENT does, so my
      # opening the thread says nothing about whether they have read me.
      {:ok, _} = Letters.write(me.id, them.id, %{kind: "text", body: "who is there"})
      render_click(live, :pick_person, %{"id" => them.id, "act" => "write"})
      assert Enum.any?(Letters.thread(me.id, them.id), &(&1.from == "you" and not &1.read))
    end
  end
end
