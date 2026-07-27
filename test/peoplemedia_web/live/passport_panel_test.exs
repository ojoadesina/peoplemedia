defmodule PeoplemediaWeb.PassportPanelTest do
  @moduledoc """
  The passport as a person meets it. `Peoplemedia.IdentityTest` proves the
  credentials; this proves the five steps in front of them hand over the right
  things, refuse the wrong ones without losing your work, and end at a cookie.
  """
  use PeoplemediaWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Peoplemedia.{Identity, People}

  @panel "/"

  defp open_passport(conn) do
    {:ok, live, _html} = live(conn, @panel)
    # The room is nested, so the flow is its own LiveView with its own id.
    find_live_child(live, "passport-panel")
  end

  defp join(pp, name, words, country \\ "Finland") do
    pp |> element(~s(button[phx-value-mode="join"])) |> render_click()
    pp |> render_change(:name, %{"name" => name})
    pp |> render_submit(:next, %{})

    pp
    |> render_change(:words, %{
      "word_0" => Enum.at(words, 0),
      "word_1" => Enum.at(words, 1),
      "word_2" => Enum.at(words, 2)
    })

    pp |> render_submit(:next, %{})
    pp |> render_change(:code, %{"code" => "4417"})
    pp |> render_submit(:next, %{})
    # Step 4 asks nothing — it shows the words back to be written down.
    pp |> render_submit(:next, %{})
    pp |> element(~s(button[phx-value-country="#{country}"])) |> render_click()
    pp |> render_submit(:next, %{})
  end

  describe "the two doors" do
    test "welcome offers request and check-in, and nothing else", %{conn: conn} do
      pp = open_passport(conn)
      html = render(pp)

      assert html =~ "REQUEST PASSPORT"
      assert html =~ "CHECK IN"
      # No fields until a door is chosen — the first screen asks one question.
      refute html =~ ~s(name="name")
    end
  end

  describe "requesting a passport" do
    test "five steps end with a person, a passport and a cookie", %{conn: conn} do
      pp = open_passport(conn)
      assert {:error, {:redirect, %{to: to}}} = join(pp, "sarah", ~w(harbour lantern thistle))

      # THE LAST STEP IS THE ONLY ONE THAT WRITES. Everything before it was held
      # in the socket; a person with no passport is a person nobody can be.
      assert to =~ "/passport/session?token="
      person = Peoplemedia.Repo.get_by!(People.Person, name: "sarah")
      assert person.country == "Finland"
      assert Identity.get_passport(person.id)

      # And the token really checks you in.
      conn = get(build_conn(), to)
      assert redirected_to(conn) == "/"
      assert Plug.Conn.get_session(conn, "person_id") == person.id
    end

    test "the name is checked as you type, because it cannot be fixed later", %{conn: conn} do
      {:ok, p} = People.create_person(%{name: "sarah"})
      {:ok, _} = Identity.create_passport(p, "sarah", ~w(harbour lantern thistle), "4417")

      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="join"])) |> render_click()

      assert pp |> render_change(:name, %{"name" => "amina"}) =~ "THAT NAME IS FREE"
      assert pp |> render_change(:name, %{"name" => "sarah"}) =~ "THAT NAME IS TAKEN"
    end

    test "a taken name will not move you on", %{conn: conn} do
      {:ok, p} = People.create_person(%{name: "sarah"})
      {:ok, _} = Identity.create_passport(p, "sarah", ~w(harbour lantern thistle), "4417")

      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="join"])) |> render_click()
      pp |> render_change(:name, %{"name" => "sarah"})

      html = pp |> render_submit(:next, %{})
      assert html =~ "TAKEN"
      # Still on step one, and still holding what was typed.
      assert html =~ "NAME · 1 OF 5"
    end

    test "three words means three DIFFERENT words, and saying so keeps them", %{conn: conn} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="join"])) |> render_click()
      pp |> render_change(:name, %{"name" => "amina"})
      pp |> render_submit(:next, %{})

      pp
      |> render_change(:words, %{
        "word_0" => "harbour",
        "word_1" => "harbour",
        "word_2" => "thistle"
      })

      html = pp |> render_submit(:next, %{})

      assert html =~ "THREE DIFFERENT WORDS"
      assert html =~ "THREE WORDS · 2 OF 5"
      # The work is not thrown away — a refusal that emptied the fields would
      # cost more than the mistake did.
      assert html =~ ~s(value="harbour")
    end

    test "a code is four digits", %{conn: conn} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="join"])) |> render_click()
      pp |> render_change(:name, %{"name" => "amina"})
      pp |> render_submit(:next, %{})

      pp
      |> render_change(:words, %{
        "word_0" => "harbour",
        "word_1" => "lantern",
        "word_2" => "thistle"
      })

      pp |> render_submit(:next, %{})

      pp |> render_change(:code, %{"code" => "441"})
      assert pp |> render_submit(:next, %{}) =~ "FOUR DIGITS"
    end

    test "the words are shown back before they are gone for good", %{conn: conn} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="join"])) |> render_click()
      pp |> render_change(:name, %{"name" => "amina"})
      pp |> render_submit(:next, %{})

      pp
      |> render_change(:words, %{
        "word_0" => "harbour",
        "word_1" => "lantern",
        "word_2" => "thistle"
      })

      pp |> render_submit(:next, %{})
      pp |> render_change(:code, %{"code" => "4417"})
      html = pp |> render_submit(:next, %{})

      assert html =~ "WRITE THESE DOWN"
      assert html =~ "HARBOUR"
      assert html =~ "YOU WILL NOT BE SHOWN THEM AGAIN"
    end

    test "back steps within the room, and out of it from the first step", %{conn: conn} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="join"])) |> render_click()
      pp |> render_change(:name, %{"name" => "amina"})
      pp |> render_submit(:next, %{})
      assert render(pp) =~ "THREE WORDS · 2 OF 5"

      assert pp |> render_click(:back, %{}) =~ "NAME · 1 OF 5"
      # From the first step, back leaves for the two doors rather than closing
      # the room — the act does that, and the two gestures must stay apart.
      assert pp |> render_click(:back, %{}) =~ "REQUEST PASSPORT"
    end
  end

  describe "checking in" do
    setup do
      {:ok, p} = People.create_person(%{name: "sarah", country: "Finland"})
      {:ok, _} = Identity.create_passport(p, "sarah", ~w(harbour lantern thistle), "4417")
      %{person: p}
    end

    test "name and word, then code, then a cookie", %{conn: conn, person: person} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="checkin"])) |> render_click()

      assert pp |> render_submit(:credentials, %{"name" => "sarah", "word" => "harbour"}) =~
               "CODE · 2 OF 2"

      assert {:error, {:redirect, %{to: to}}} = pp |> render_submit(:verify, %{"code" => "4417"})
      assert to =~ "/passport/session?token="

      conn = get(build_conn(), to)
      assert Plug.Conn.get_session(conn, "person_id") == person.id
    end

    test "a wrong word does not say which half was wrong", %{conn: conn} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="checkin"])) |> render_click()

      wrong_word = pp |> render_submit(:credentials, %{"name" => "sarah", "word" => "nope"})
      unknown = pp |> render_submit(:credentials, %{"name" => "nobody", "word" => "harbour"})

      assert wrong_word =~ "DO NOT GO TOGETHER"
      assert unknown =~ "DO NOT GO TOGETHER"
    end

    test "a wrong code holds you at step two and does not spend the word", %{conn: conn} do
      pp = open_passport(conn)
      pp |> element(~s(button[phx-value-mode="checkin"])) |> render_click()
      pp |> render_submit(:credentials, %{"name" => "sarah", "word" => "harbour"})

      assert pp |> render_submit(:verify, %{"code" => "0000"}) =~ "WRONG CODE"

      # The word survived, so the right code still works.
      assert {:error, {:redirect, _}} = pp |> render_submit(:verify, %{"code" => "4417"})
    end
  end
end
