defmodule PeoplemediaWeb.PassportPanelTest do
  @moduledoc """
  The passport room, on both sides of the one branch it has.

  It only ever had one side. Somebody already checked in was shown REQUEST
  PASSPORT and CHECK IN — two doors into a room they were standing in — and had
  no way to see or top up the word bank, which is the entire recovery story of a
  scheme with no email in it.
  """
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  test "checked in, the passport room is about the passport you have" do
    me = cast()
    {:ok, _live, html} = live(check_in(build_conn(), me), ~p"/")

    assert html =~ "WORD BANK"
    assert html =~ "CHECK OUT"
    assert html =~ "ADD MORE WORDS"
    refute html =~ "REQUEST PASSPORT"
  end

  test "a visitor still gets the two doors" do
    {:ok, _live, html} = live(build_conn(), ~p"/")
    assert html =~ "REQUEST PASSPORT"
    assert html =~ "CHECK IN"
    refute html =~ "WORD BANK"
  end

  test "the roll of places admits somewhere it never listed" do
    # DETECTION CAN PUT SOMEBODY ANYWHERE, and the roll was a closed set of
    # eighteen. Somebody in the nineteenth country was present in the data and
    # absent from the only control that finds them.
    me = cast()
    person("VISITOR", "Iceland")

    names = Enum.map(Peoplemedia.Directory.countries(me), & &1.name)
    assert "Iceland" in names
    assert "Finland" in names

    # And the box counts it rather than answering with the world's totals.
    assert %{name: "Iceland", unscopes: 1} = Peoplemedia.Directory.population_of(me, "Iceland")
  end

  test "the country step is detected, not picked from a list" do
    {:ok, live, html} = live(build_conn(), ~p"/")

    # NOBODY IS ASKED FOR THEIR LOCATION BY A ROOM THEY OPENED TO LOOK AT. The
    # hook lives inside the sign-up flow only, so a permission prompt is a
    # consequence of asking for a passport rather than of opening the app.
    refute html =~ ~s(phx-hook="Geolocation")

    pp = find_live_child(live, "passport-panel")
    joining = render_click(pp, :choose, %{"mode" => "join"})

    assert joining =~ ~s(phx-hook="Geolocation")
    # The eighteen chips are gone; there is nothing to press.
    refute joining =~ ~s(phx-click="country")
  end

  test "the last step is gated on a place, and a refusal keeps a way back" do
    {:ok, live, _} = live(build_conn(), ~p"/")
    pp = find_live_child(live, "passport-panel")
    render_click(pp, :choose, %{"mode" => "join"})

    # All the way to the country step, which is the only one that can be
    # blocked by something outside the person's hands.
    render_change(pp, :name, %{"name" => "wanderer"})
    render_submit(pp, :next, %{})
    render_change(pp, :words, %{"word_0" => "cedar", "word_1" => "willow", "word_2" => "thistle"})
    render_submit(pp, :next, %{})
    render_change(pp, :code, %{"code" => "1234"})
    render_submit(pp, :next, %{})
    html = render_submit(pp, :next, %{})

    assert html =~ "HOME · 5 OF 5"
    # Nothing known yet, so nothing to commit — the forward button sleeps.
    assert forward_of(html) =~ ~r/\sdisabled/

    refused = render_hook(pp, "geo_error", %{"code" => 1})
    assert refused =~ "Location is off for this site"
    # A REFUSAL IS A GATE, NOT A WALL. There is something to press, and the hook
    # is separately listening for the permission to flip on its own — so
    # changing your mind in the address bar unsticks this without a reload.
    assert refused =~ ~s(phx-click="retry_location")
    assert forward_of(refused) =~ ~r/\sdisabled/

    # A LIST APPEARS ONLY ONCE DETECTION HAS FAILED, because the last step of
    # signing up must be finishable. It is not the question this step asks — the
    # device already knows — it is the way out for a browser that said no.
    assert refused =~ ~s(phx-click="country")
    picked = render_click(pp, :country, %{"country" => "Finland"})
    refute forward_of(picked) =~ ~r/\sdisabled(?![:\w-])/

    # And a place clears it.
    ready = render_hook(pp, "geo", %{"lat" => 60.17, "lng" => 24.94})
    refute forward_of(ready) =~ ~r/\sdisabled(?![:\w-])/
  end

  test "the whole request, end to end, lands you signed in" do
    # THE ONE TEST THAT WOULD HAVE CAUGHT IT. Every part of this was proved
    # separately and the whole was never walked, so nobody noticed that a
    # passport could not actually be got.
    conn = build_conn()
    {:ok, live, _} = live(conn, ~p"/")
    pp = find_live_child(live, "passport-panel")

    render_click(pp, :choose, %{"mode" => "join"})
    render_change(pp, :name, %{"name" => "cynthia"})
    render_submit(pp, :next, %{})
    render_change(pp, :words, %{"word_0" => "cedar", "word_1" => "willow", "word_2" => "thistle"})
    render_submit(pp, :next, %{})
    render_change(pp, :code, %{"code" => "1234"})
    render_submit(pp, :next, %{})
    render_submit(pp, :next, %{})
    render_hook(pp, "geo", %{"lat" => 60.17, "lng" => 24.94})

    {:error, {:redirect, %{to: to}}} = render_submit(pp, :next, %{})

    # A LiveView cannot set a cookie, so the last act of signing up is a real
    # request. Following it is the only way to prove the passport is usable.
    followed = get(conn, to)
    assert redirected_to(followed) == "/"
    home = followed |> recycle() |> get("/")
    assert html_response(home, 200) =~ "WORD BANK"

    # And it is a passport, not just a session — it opens again from cold.
    assert {:ok, passport, sid} = Peoplemedia.Identity.check_key("cynthia", "cedar")
    assert {:ok, %{name: "cynthia"}} = Peoplemedia.Identity.check_code(passport, "1234", sid)
  end

  test "a word the write would refuse is refused where it can still be fixed" do
    {:ok, live, _} = live(build_conn(), ~p"/")
    pp = find_live_child(live, "passport-panel")

    render_click(pp, :choose, %{"mode" => "join"})
    render_change(pp, :name, %{"name" => "cynthia"})
    render_submit(pp, :next, %{})

    # `create_passport` insists on letters only, and this step used to check
    # only length and uniqueness — so a word with a digit in it passed here and
    # failed three screens later, with the error landing on the country step
    # about a field no longer on screen.
    render_change(pp, :words, %{"word_0" => "cedar1", "word_1" => "willow", "word_2" => "thistle"})

    assert render_submit(pp, :next, %{}) =~ "LETTERS ONLY"
  end

  test "a passport that cannot be made leaves no half a person behind" do
    # The person and the passport were two writes with a `with` between them, so
    # a failed passport left a name nobody could ever sign into — and a second
    # attempt made a second one.
    {:ok, live, _} = live(build_conn(), ~p"/")
    pp = find_live_child(live, "passport-panel")

    render_click(pp, :choose, %{"mode" => "join"})
    render_change(pp, :name, %{"name" => "cynthia"})
    render_submit(pp, :next, %{})
    render_change(pp, :words, %{"word_0" => "cedar", "word_1" => "willow", "word_2" => "thistle"})
    render_submit(pp, :next, %{})
    render_change(pp, :code, %{"code" => "1234"})
    render_submit(pp, :next, %{})
    render_submit(pp, :next, %{})
    render_hook(pp, "geo", %{"lat" => 60.17, "lng" => 24.94})

    # Claim the handle from under it, so the passport cannot be written.
    other = person("someoneelse")

    {:ok, _} =
      Peoplemedia.Identity.create_passport(other, "cynthia", ~w(alpha beta gamma), "9999")

    assert render_submit(pp, :next, %{}) =~ "NAME"
    refute Enum.any?(Peoplemedia.Repo.all(Peoplemedia.People.Person), &(&1.name == "cynthia"))
  end

  defp forward_of(html),
    do: Regex.run(~r/<button[^>]*form="pp-step".*?>/s, html) |> List.first()

  test "topping up adds words to the bank" do
    me = cast()
    {:ok, live, _} = live(check_in(build_conn(), me), ~p"/")
    pp = find_live_child(live, "passport-panel")

    before = Peoplemedia.Identity.get_passport(me.id).secrets |> length()
    render_submit(pp, :add_words, %{"words" => "cedar willow"})
    assert Peoplemedia.Identity.get_passport(me.id).secrets |> length() == before + 2
  end
end
