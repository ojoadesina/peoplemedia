defmodule PeoplemediaWeb.Plugs.PassportAuthTest do
  @moduledoc """
  The session end of the passport. The identity tests prove the credentials; this
  proves that being signed in survives the trip through a cookie, and that the
  token bridge cannot be walked over by anyone holding a stale or forged token.
  """
  use PeoplemediaWeb.ConnCase, async: true

  alias Peoplemedia.People
  alias PeoplemediaWeb.Plugs.PassportAuth

  defp person do
    {:ok, p} = People.create_person(%{name: "Sarah", country: "Finland"})
    p
  end

  defp with_session(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.fetch_session()
  end

  describe "current_person" do
    test "is nil for a visitor, and the surface still opens", %{conn: conn} do
      conn = conn |> with_session() |> PassportAuth.fetch_current_person([])
      assert conn.assigns.current_person == nil

      # THE LIST IS PUBLIC. If this ever redirects, the app has grown a wall.
      # Asserted on a fragment without the apostrophe: the dead render emits a
      # literal ' where the LiveView render emits &#39;, and this route is the
      # one place both paths are exercised.
      assert html_response(get(build_conn(), ~p"/"), 200) =~ "DO LIFE ALONE"
    end

    test "is the person whose id the session holds", %{conn: conn} do
      p = person()

      conn =
        conn
        |> with_session()
        |> PassportAuth.create_session(p)
        |> PassportAuth.fetch_current_person([])

      assert conn.assigns.current_person.id == p.id
    end

    test "is nil again once the session is destroyed", %{conn: conn} do
      conn =
        conn
        |> with_session()
        |> PassportAuth.create_session(person())
        |> PassportAuth.destroy_session()
        |> PassportAuth.fetch_current_person([])

      assert conn.assigns.current_person == nil
    end

    test "survives a person being deleted rather than crashing", %{conn: conn} do
      p = person()
      conn = conn |> with_session() |> PassportAuth.create_session(p)
      Peoplemedia.Repo.delete!(p)

      assert PassportAuth.fetch_current_person(conn, []).assigns.current_person == nil
    end
  end

  describe "the token bridge" do
    test "a signed token checks you in and lands you on the surface", %{conn: conn} do
      p = person()
      token = PassportAuth.generate_session_token(PeoplemediaWeb.Endpoint, p.id)

      conn = get(conn, ~p"/passport/session", %{"token" => token})
      assert redirected_to(conn) == "/"
      assert Plug.Conn.get_session(conn, "person_id") == p.id
    end

    test "it honours a return_to", %{conn: conn} do
      token = PassportAuth.generate_session_token(PeoplemediaWeb.Endpoint, person().id)
      conn = get(conn, ~p"/passport/session", %{"token" => token, "return_to" => "/logo"})
      assert redirected_to(conn) == "/logo"
    end

    test "a forged token checks nobody in", %{conn: conn} do
      conn = get(conn, ~p"/passport/session", %{"token" => "not-a-token"})
      assert redirected_to(conn) == "/passport/check-in"
      refute Plug.Conn.get_session(conn, "person_id")
    end

    test "a token for someone who no longer exists checks nobody in", %{conn: conn} do
      p = person()
      token = PassportAuth.generate_session_token(PeoplemediaWeb.Endpoint, p.id)
      Peoplemedia.Repo.delete!(p)

      conn = get(conn, ~p"/passport/session", %{"token" => token})
      assert redirected_to(conn) == "/passport/check-in"
      refute Plug.Conn.get_session(conn, "person_id")
    end

    test "checking out clears the session", %{conn: conn} do
      p = person()
      token = PassportAuth.generate_session_token(PeoplemediaWeb.Endpoint, p.id)
      conn = get(conn, ~p"/passport/session", %{"token" => token})
      assert Plug.Conn.get_session(conn, "person_id") == p.id

      conn = delete(recycle(conn), ~p"/passport/check-out")
      refute Plug.Conn.get_session(conn, "person_id")
    end
  end

  describe "require_auth" do
    test "turns a visitor away", %{conn: conn} do
      conn =
        conn
        |> with_session()
        |> Phoenix.ConnTest.fetch_flash()
        |> PassportAuth.fetch_current_person([])
        |> PassportAuth.require_auth([])

      assert conn.halted
      assert redirected_to(conn) == "/passport/check-in"
    end

    test "lets a checked-in person through untouched", %{conn: conn} do
      conn =
        conn
        |> with_session()
        |> PassportAuth.create_session(person())
        |> PassportAuth.fetch_current_person([])
        |> PassportAuth.require_auth([])

      refute conn.halted
    end
  end
end
