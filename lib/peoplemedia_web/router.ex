defmodule PeoplemediaWeb.Router do
  use PeoplemediaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PeoplemediaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PeoplemediaWeb do
    pipe_through :browser

    live "/", IndexLive
    # A reference exhibit of the old recorder UI, kept only while it is being
    # mined for ideas. Not a feature; delete the route with the module.
    live "/recorder", RecorderLive
    # The two candidate marks, at size, on both surfaces. Plug.Static serves the
    # files under /logo but resolves no directory index, so the sheet needs a
    # route of its own. Delete it with the module once a logo is chosen.
    live "/logo", LogoLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", PeoplemediaWeb do
  #   pipe_through :api
  # end
end
