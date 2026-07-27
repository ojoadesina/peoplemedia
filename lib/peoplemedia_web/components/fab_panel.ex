defmodule PeoplemediaWeb.FabPanel do
  @moduledoc """
  THE FAB PANEL — what the act opens.

  It is named for the button rather than for its contents, because its contents
  are a registry and will keep growing. What it is NOT is `#panel`, which opens
  under the header when a relationship is picked up: that one is about a person,
  this one is about the app. Two panels doing two jobs, and the names have to
  say which.

  ## ONE OVERLAY, MANY BODIES

  Every room carries `data-panel-body="x"`; anything carrying
  `data-panel-open="x"` opens it. Adding a room later is one cell in the
  launcher and one body — no new JavaScript. `fab_panel.ts` holds the whole
  mechanism in about eighty lines, and it carried five rooms in the project this
  was lifted from.

  ## IT IS OPAQUE

  The panel it was ported from floated on a 90% white wash so the world stayed
  half-visible behind it — which is right when the thing behind is a living map
  you are reading THROUGH the panel. Here the thing behind is a list of names,
  and a half-visible list under a passport form is neither readable nor ignorable.
  This ground is the page's own colour at full strength: while a room is open,
  it is the only thing on screen.

  ## THE ACT IS THE ONLY CONTROL

  There is no separate close button. The plus at the bottom left turns 45
  degrees into a cross over the launcher, and becomes an arrow inside a room —
  one button, three answers. The alternative was the two the reference used (a
  floating opener and a foot that closed or stepped back), and two controls a
  thumb's width apart, both about the same panel, is one more than the gesture
  needs. It also keeps this surface's own rule: the thing you pressed is the
  thing that answers.
  """
  # `use Phoenix.Component`, NOT `use PeoplemediaWeb, :html` — the latter imports
  # this module, and a module cannot import itself while it is being defined.
  # CoreComponents sits on the same footing for the same reason.
  use Phoenix.Component

  @doc """
  The panel and its rooms. `current_person` decides which cells the launcher
  offers — there is no point showing someone a passport manager before they have
  a passport.
  """
  attr :current_person, :any, default: nil
  attr :unread, :integer, default: 0

  def fab_panel(assigns) do
    ~H"""
    <div
      id="fab-panel"
      phx-hook="FabPanel"
      class="fab-panel pointer-events-none fixed inset-0 z-40"
      aria-hidden="true"
    >
      <%!-- NOT phx-update="ignore", deliberately. The launcher's contents are
           the server's to say — whether you are checked in, how much is
           waiting — so ignoring patches would freeze it at whatever it said
           when the page loaded. The hook re-stamps itself after every patch
           instead, which is what `updated/0` is for. aria-hidden is set from
           the same place, because a closed panel is not there and an open one
           is the only thing on screen. --%>
      <%!-- THE GROUND, at the page's own colour and full strength. It fades
           rather than appearing, so opening reads as the page being covered
           rather than as a new page arriving. --%>
      <div class="fab-ground absolute inset-0 bg-light-50 dark:bg-dark-950"></div>

      <%!-- The rooms wear the RAIL, so every word in here starts on the edge
           the mark, the strapline and the list all start from. A panel that
           measured itself would be a sixth left edge. --%>
      <div class="fab-rooms rail relative flex h-full flex-col pt-(--body-top) pb-(--fab-foot)">
        <%!-- ── THE LAUNCHER ───────────────────────────────────────────────
             Every door the app has, as a grid of squares. Squares because
             everything here is square; a wash rather than an outline because
             that is what a pressable box looks like on this surface; and the
             label under each in the same small tracked type the counts use.

             The reference drew these as circles with ring icons in stroke
             weight — a different vocabulary entirely, and one that would have
             read as somebody else's app dropped into this one. --%>
        <div data-panel-body="launcher" class="fab-body min-h-0 flex-1 overflow-y-auto" hidden>
          <p class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            {(@current_person && String.upcase(@current_person.name)) || "NOT CHECKED IN"}
          </p>

          <div class="mt-8 grid grid-cols-3 gap-4 sm:grid-cols-4">
            <.cell
              name="passport"
              label={(@current_person && "PASSPORT") || "CHECK IN"}
              badge={0}
            >
              <%!-- A passport is a held thing with a mark in it: the box, and
                   the two eyes of the app's own head sitting inside. --%>
              <rect
                x="3"
                y="5"
                width="18"
                height="14"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              />
              <rect x="7" y="10" width="3.5" height="3.5" />
              <rect x="13.5" y="10" width="3.5" height="3.5" />
            </.cell>

            <.cell name="scoping" label="SCOPING" badge={@unread}>
              <%!-- The two intersected rings, square — the same mark the list
                   used for its scope lens before the boxes took over. --%>
              <rect
                x="3.5"
                y="7"
                width="10"
                height="10"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              />
              <rect
                x="10.5"
                y="7"
                width="10"
                height="10"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              />
            </.cell>
          </div>
        </div>

        <%!-- ── THE ROOMS ──────────────────────────────────────────────────
             Reachable, and deliberately empty until the work that fills them
             lands. An empty room you can open and step back out of proves the
             mechanism; a cell that opens nothing would not. --%>
        <div data-panel-body="passport" class="fab-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>PASSPORT</.room_title>
          <p class="mt-6 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            CHECK IN AND REQUEST ARRIVE NEXT
          </p>
        </div>

        <div data-panel-body="scoping" class="fab-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>SCOPING</.room_title>
          <p class="mt-6 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            SWIPE A NAME TO SCOPE THEM
          </p>
        </div>
      </div>
    </div>
    """
  end

  # A launcher cell: a square of wash, a mark cut out of it, a word underneath.
  # The badge rides the corner and only ever appears — nothing here opens
  # uninvited.
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :badge, :integer, default: 0
  slot :inner_block, required: true

  defp cell(assigns) do
    ~H"""
    <button
      type="button"
      data-panel-open={@name}
      class="group flex cursor-pointer flex-col items-center gap-3 outline-none"
    >
      <span class={[
        "fab-cell relative flex aspect-square w-full items-center justify-center",
        "bg-primary-600/15 text-primary-600 transition-colors",
        "group-hover:bg-primary-600/25 group-focus-visible:bg-primary-600/25",
        "dark:bg-primary-500/20 dark:text-primary-500",
        "dark:group-hover:bg-primary-500/30 dark:group-focus-visible:bg-primary-500/30"
      ]}>
        <svg viewBox="0 0 24 24" class="h-2/5 w-2/5" fill="currentColor" aria-hidden="true">
          {render_slot(@inner_block)}
        </svg>
        <span
          :if={@badge > 0}
          class="fab-badge absolute top-0 right-0 flex min-w-5 -translate-y-1/3 translate-x-1/3 items-center justify-center bg-primary-600 px-1 text-(length:--text-xs) text-primary-50 dark:bg-primary-500"
        >
          {(@badge > 9 && "9+") || @badge}
        </span>
      </span>
      <span class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-500 transition-colors group-hover:text-neutral-600 dark:text-neutral-400 dark:group-hover:text-neutral-300">
        {@label}
      </span>
    </button>
    """
  end

  slot :inner_block, required: true

  defp room_title(assigns) do
    ~H"""
    <p class="text-(length:--count-type) leading-none font-bold tracking-(--row-track) text-light-900 dark:text-dark-100">
      {render_slot(@inner_block)}
    </p>
    """
  end
end
