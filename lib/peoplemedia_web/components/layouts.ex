defmodule PeoplemediaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PeoplemediaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-light-50 text-light-900 dark:bg-dark-950 dark:text-dark-100">
      <header class="flex items-center gap-4 border-b border-light-200 px-4 py-3 sm:px-6 lg:px-8 dark:border-dark-800">
        <div class="flex-1">
          <a href="/" class="flex w-fit items-center gap-2">
            <img src={~p"/images/logo.svg"} width="36" />
            <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
          </a>
        </div>
        <div class="flex-none">
          <ul class="flex items-center gap-4 px-1">
            <li>
              <a
                href="https://phoenixframework.org/"
                class="rounded-md px-3 py-2 text-md font-medium text-light-700 transition-colors hover:bg-light-100 dark:text-dark-300 dark:hover:bg-dark-900"
              >
                Website
              </a>
            </li>
            <li>
              <a
                href="https://github.com/phoenixframework/phoenix"
                class="rounded-md px-3 py-2 text-md font-medium text-light-700 transition-colors hover:bg-light-100 dark:text-dark-300 dark:hover:bg-dark-900"
              >
                GitHub
              </a>
            </li>
            <li>
              <.theme_toggle />
            </li>
            <li>
              <.button variant="primary" href="https://hexdocs.pm/phoenix/overview.html">
                Get Started <span aria-hidden="true">&rarr;</span>
              </.button>
            </li>
          </ul>
        </div>
      </header>

      <main class="px-4 py-20 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-2xl space-y-4">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides a system/light/dark theme toggle.

  The three positions are SYSTEM, LIGHT and DARK in that order, and the pill
  slides to whichever is active. System is the leftmost because it is the
  default: the inline script in `root.html.heex` writes `data-theme` onto
  `<html>` for an explicit choice and removes it for system, so "no attribute"
  is the resting state and the pill sits at `left-0` to match.

  Nothing here belongs to a component library — the attribute this reads is our
  own, and `app.css` derives the `dark:` variant from the very same two
  conditions (explicit `data-theme=dark`, or no attribute plus an OS that
  prefers dark).

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center rounded-full border-2 border-light-200 bg-light-200 dark:border-dark-800 dark:bg-dark-950">
      <div class="absolute left-0 h-full w-1/3 rounded-full border border-light-100 bg-light-50 transition-[left] in-data-[theme=light]:left-1/3 in-data-[theme=dark]:left-2/3 dark:border-dark-800 dark:bg-dark-950" />

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="Use system theme"
      >
        <.icon
          name="hero-computer-desktop-micro"
          class="relative size-4 opacity-75 hover:opacity-100"
        />
      </button>

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Use light theme"
      >
        <.icon name="hero-sun-micro" class="relative size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Use dark theme"
      >
        <.icon name="hero-moon-micro" class="relative size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
