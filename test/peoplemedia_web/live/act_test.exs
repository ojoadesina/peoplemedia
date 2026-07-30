defmodule PeoplemediaWeb.ActTest do
  @moduledoc """
  THE FOOT, AND YOUR OWN PAGE.

  Three buttons, and each of them means one thing. The act goes round — in place,
  with no panel — and what it produces is `RoundTest`'s subject; what is left here
  is the furniture around it: that the three doors are where they should be, that
  the count rides the one that can discharge it, and that a receipt survives the
  patch it arrives with.
  """
  use PeoplemediaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Peoplemedia.Fixtures

  alias Peoplemedia.{Letters, Notifications, Relationships}

  setup %{conn: conn} do
    me = cast()
    %{conn: check_in(conn, me), me: me}
  end

  describe "your own page" do
    test "the self button opens it over your own name and closes it again", %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/")
      refute has_element?(live, "#panel")

      live |> element("#self") |> render_click()
      assert has_element?(live, "#panel")
      # The header carries your own name — a label is what you call somebody
      # else, and you do not call yourself anything.
      assert live |> element(".focus-name") |> render() =~ "OJO"

      live |> element("#self") |> render_click()
      refute has_element?(live, "#panel")
    end

    test "it holds your letterheads, newest first, and nothing you wrote to one person", %{
      conn: conn,
      me: me
    } do
      [{_scope, them} | _] = Relationships.held_by(me.id)
      {:ok, _} = Letters.broadcast(me.id, "world", %{kind: "text", body: "the older one"})
      {:ok, _} = Letters.broadcast(me.id, "world", %{kind: "text", body: "the newer one"})
      {:ok, _} = Letters.write(me.id, them.id, %{kind: "text", body: "just for you"})

      {:ok, live, _} = live(conn, ~p"/")
      page = live |> element("#self") |> render_click()

      # Two rows, both yours, newest at the top — and the letter to one person
      # is not among them. It lives on their page, where the answers to it are.
      assert page |> String.split(~s(class="panel-item)) |> length() == 3
      refute page =~ "just for you"
    end

    # A page is the letters you have written, and a visitor cannot have written
    # any — so there is no button rather than a button that says no.
    test "a visitor has none", %{conn: _conn} do
      {:ok, live, _} = live(build_conn(), ~p"/")
      refute has_element?(live, "#self")
    end
  end

  describe "the foot" do
    test "the act writes and the more button opens the launcher", %{conn: conn, me: me} do
      # ONE MARK, ONE PROMISE. The plus said MAKE SOMETHING and opened a drawer;
      # it makes something now, and the drawer has a door of its own.
      {:ok, live, _} = live(conn, ~p"/")

      # THE ACT OPENS NO PANEL. It used to carry `data-open-room`, which handed
      # it to the launcher's registry; going round happens on the surface now,
      # so the only thing it names is a handler.
      assert has_element?(live, ~s(#act[phx-click="go_round"]))
      refute has_element?(live, ~s(#act[data-open-room]))
      assert has_element?(live, "#more")
      assert has_element?(live, ~s(#self[phx-click="open_self"]))

      # THE COUNT RIDES THE DOOR, and the door moved. Left on the act it would
      # be a badge on a button that cannot discharge it.
      {:ok, _} = Notifications.notify(me.id, "scope_request", nil)
      send(live.pid, :stir)

      assert has_element?(live, "#more .launcher-badge")
      refute has_element?(live, "#act .launcher-badge")
    end

    # THE RECEIPT HAS TO SURVIVE THE PATCH IT ARRIVES WITH. The toast element's
    # `class` and `hidden` are exempt because the hook writes them — but the
    # LINE inside is an ordinary child the server renders blank, so any patch in
    # the six-second window wiped the sentence and left an empty terracotta box
    # on screen. Opening a panel was enough to do it.
    test "the toast's words are the client's, and a patch cannot take them" do
      markup = File.read!("lib/peoplemedia_web/live/index_live.ex")
      line = Regex.run(~r/<p\s+id="toast-line"[\s\S]{0,200}/, markup) |> List.first()

      assert line =~ ~s(phx-update="ignore"),
             "a patch will blank the receipt and leave the box"
    end

    # The strings that cross from Elixir into TypeScript, checked on both sides
    # — the house has been bitten by exactly that before, and a rename is not a
    # safe operation on one.
    test "the launcher hook reaches for the button that now opens it" do
      hook = File.read!("assets/js/hooks/launcher.ts")
      assert hook =~ ~s|getElementById("more")|, "the launcher's door is the more button"
      assert hook =~ ~s|querySelector<HTMLElement>(".app-foot")|
    end

    # WITHOUT THIS THE TARGETED LETTER HAS NO DOOR. The foot used to fade out
    # with the header when a panel opened, on the reasoning that an act over an
    # open conversation points at nothing — which this feature inverts exactly.
    test "the foot does not fade out behind a panel" do
      css = File.read!("assets/css/app.css")

      refute css =~ "#scopes.is-open .app-foot",
             "the act must stay while a panel is open, or it cannot write to the person in it"

      assert css =~ "#scopes.is-open .app-head"
    end

    # THE BUG THIS CAUGHT, WHICH LOOKED LIKE A HAUNTING. `is-away` moved from
    # the act to the row around it, and `pointer-events: none` on a parent is
    # not a thing a child cannot undo — all three buttons set
    # `pointer-events-auto` to opt in, so they kept taking presses at zero
    # opacity. The foot is z-50 and the launcher's own foot is z-20 at the same
    # `bottom`, so pressing the launcher's X pressed the ACT sitting invisibly
    # on top of it, and the write room opened for no reason anybody could see.
    test "the buttons stop taking presses when the foot steps aside" do
      css = File.read!("assets/css/app.css")

      assert css =~ ".app-foot.is-away button",
             "the buttons must lose pointer-events, not the row — they opt back in"
    end

    # An empty check invites an act and then refuses it, which is the fault the
    # row's own SCOPE word was fixed for. The browser knows the field is empty;
    # asking the server would be a round trip per keystroke.
    test "the check is not offered until there is a letter" do
      css = File.read!("assets/css/app.css")
      assert css =~ ~s|:has(.compose-field:placeholder-shown)|
      assert File.read!("lib/peoplemedia_web/components/launcher.ex") =~ "compose-field"
    end
  end
end
