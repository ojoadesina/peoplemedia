defmodule PeoplemediaWeb.Router do
  use PeoplemediaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PeoplemediaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Every browser request learns who is signed in, including "nobody". The
    # list is public and auth-aware — you can read the surface before you have a
    # passport — so this assigns rather than guards.
    plug PeoplemediaWeb.Plugs.PassportAuth, :fetch_current_person
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PeoplemediaWeb do
    pipe_through :browser

    # THE SURFACE IS PUBLIC. `:assign_current_person` puts whoever is signed in
    # on the socket without requiring anyone to be — the same answer the HTTP
    # pipeline gives, asked again because a LiveView does not run that pipeline.
    live_session :surface,
      on_mount: {PeoplemediaWeb.Plugs.PassportAuth, :assign_current_person} do
      live "/", IndexLive

      # THE FRAME, being tried at size before it replaces the list. In here rather
      # than beside the other two exhibits below, because it draws the SAME people
      # the surface draws — and outside this session it was handed the visitor's
      # answer, which is everybody and nobody's letters. An exhibit fed different
      # data from the thing it is standing in for is not an exhibit.
      #
      # Same terms as those two otherwise: a route that exists to settle a
      # decision, deleted with the module once it is settled.
      live "/ui", UiLive
    end

    # A reference exhibit of the old recorder UI, kept only while it is being
    # mined for ideas. Not a feature; delete the route with the module.
    live "/recorder", RecorderLive
    # The two candidate marks, at size, on both surfaces. Plug.Static serves the
    # files under /logo but resolves no directory index, so the sheet needs a
    # route of its own. Delete it with the module once a logo is chosen.
    live "/logo", LogoLive

    # THE TOKEN BRIDGE, and the way out. A LiveView cannot set a cookie, so it
    # signs a token and sends you through here; check-out just clears it.
    get "/passport/session", PassportSessionController, :create
    delete "/passport/check-out", PassportSessionController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", PeoplemediaWeb do
  #   pipe_through :api
  # end
end
