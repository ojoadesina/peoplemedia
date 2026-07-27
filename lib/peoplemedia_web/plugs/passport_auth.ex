defmodule PeoplemediaWeb.Plugs.PassportAuth do
  @moduledoc """
  Who is signed in. The session holds a `person_id` and nothing else; everything
  downstream reads `current_person`, which is a `Peoplemedia.People.Person` or nil.

  THE SESSION HOLDS AN ID, NOT A PASSPORT. A passport is the auth record — hashed
  code, word bank, lockouts — and no part of the app that merely wants to know
  "who am I" should be carrying it. The id is looked up fresh on every request,
  so a person whose row has changed is not walking around with a stale copy of
  themselves in a cookie.

  Three ways in, differing only in what happens when nobody is signed in:

    * `fetch_current_person` — assigns whoever it finds, including nil. The list
      is PUBLIC and auth-aware: you can read the surface before you have a
      passport, which is the whole reason this app has a check-in flow rather
      than a wall.
    * `require_auth` — for the things only a signed-in person can do.
    * `redirect_if_authenticated` — for the check-in pages themselves.

  Each has an `on_mount` twin, because a LiveView does not run the HTTP pipeline
  and has to ask the same question again from its session.

  ## THE TOKEN BRIDGE

  A LiveView cannot set a cookie — by the time it is running, the response
  headers are long gone. So a LiveView that has just authenticated signs a
  short-lived token and redirects to `PassportSessionController`, which IS a real
  request and can. Sixty seconds is deliberately mean: the token's only job is to
  survive one redirect, and a sign-in token that outlives that is a sign-in token
  somebody can post to you.
  """
  import Plug.Conn, except: [assign: 3]

  alias Peoplemedia.People

  @session_key "person_id"

  def init(opts), do: opts
  def call(conn, action), do: apply(__MODULE__, action, [conn, []])

  # ── HTTP plugs ──────────────────────────────────────────────────────────────
  def fetch_current_person(conn, _opts) do
    Plug.Conn.assign(conn, :current_person, load_person(get_session(conn, @session_key)))
  end

  def require_auth(conn, _opts) do
    if conn.assigns[:current_person] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Check in to do that.")
      |> Phoenix.Controller.redirect(to: "/passport/check-in")
      |> halt()
    end
  end

  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_person] do
      conn |> Phoenix.Controller.redirect(to: "/") |> halt()
    else
      conn
    end
  end

  # ── Session helpers ─────────────────────────────────────────────────────────
  def create_session(conn, person), do: put_session(conn, @session_key, person.id)
  def destroy_session(conn), do: delete_session(conn, @session_key)

  def generate_session_token(socket, person_id),
    do: Phoenix.Token.sign(socket, "passport_session", person_id)

  def verify_session_token(conn, token),
    do: Phoenix.Token.verify(conn, "passport_session", token, max_age: 60)

  # ── LiveView on_mount ───────────────────────────────────────────────────────
  def on_mount(:assign_current_person, _params, session, socket) do
    {:cont, Phoenix.Component.assign(socket, :current_person, load_person(session[@session_key]))}
  end

  def on_mount(:require_auth, _params, session, socket) do
    case load_person(session[@session_key]) do
      nil -> {:halt, Phoenix.LiveView.redirect(socket, to: "/passport/check-in")}
      person -> {:cont, Phoenix.Component.assign(socket, :current_person, person)}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    if load_person(session[@session_key]) do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    else
      {:cont, Phoenix.Component.assign(socket, :current_person, nil)}
    end
  end

  defp load_person(nil), do: nil
  defp load_person(id), do: People.get_person(id)
end
