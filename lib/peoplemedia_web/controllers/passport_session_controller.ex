defmodule PeoplemediaWeb.PassportSessionController do
  @moduledoc """
  The far side of the token bridge. A LiveView authenticates, signs a
  short-lived token and redirects here; this is a real request, so it can verify
  the token and set the cookie a LiveView never could.

  It re-loads the person rather than trusting the token to carry anything but an
  id, and a token that fails to verify — expired, tampered with, or for someone
  since deleted — lands you back at check-in rather than anywhere useful.
  """
  use PeoplemediaWeb, :controller

  alias Peoplemedia.People
  alias PeoplemediaWeb.Plugs.PassportAuth

  def create(conn, %{"token" => token} = params) do
    with {:ok, person_id} <- PassportAuth.verify_session_token(conn, token),
         person when not is_nil(person) <- People.get_person(person_id) do
      conn
      |> PassportAuth.create_session(person)
      |> put_flash(:info, "Welcome, #{person.name}.")
      |> redirect(to: Map.get(params, "return_to", "/"))
    else
      _ ->
        conn
        |> put_flash(:error, "That sign-in link was invalid or expired.")
        |> redirect(to: "/passport/check-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> PassportAuth.destroy_session()
    |> put_flash(:info, "Checked out.")
    |> redirect(to: "/")
  end
end
