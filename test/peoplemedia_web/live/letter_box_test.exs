defmodule PeoplemediaWeb.LetterBoxTest do
  @moduledoc """
  The letter box has now been broken twice by the same kind of mistake — a
  string or an attribute that crosses from Elixir to the browser and is only
  checked on one side. Both halves are asserted here.
  """
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  test "the box survives the patch its own settle causes" do
    me = cast()
    {:ok, live, html} = live(check_in(build_conn(), me), ~p"/")

    # The server always renders it empty — it cannot know where the list has
    # settled — so the hook writes the truth over it, and the patch caused by
    # the settle used to write the server's copy straight back.
    box = Regex.run(~r/<div[^>]*id="letterbox".*?>/s, html) |> List.first()
    assert box =~ "is-empty"
    assert box =~ "ignore_attrs", "a patch will wipe the letter the hook just put there"

    hook = File.read!("assets/js/hooks/scopes.ts")
    assert hook =~ "showLetter(focused)", "a patch must put the letter back, not just the mark"
  end
end
