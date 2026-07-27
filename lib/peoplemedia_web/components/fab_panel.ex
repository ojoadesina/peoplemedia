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

  # The mark, and only the mark. A blanket `import CoreComponents` would be a
  # cycle waiting to happen the day CoreComponents wants anything from here.
  import PeoplemediaWeb.CoreComponents, only: [head: 1]

  @doc """
  The panel and its rooms. `current_person` decides which cells the launcher
  offers — there is no point showing someone a passport manager before they have
  a passport.
  """
  attr :socket, :map, required: true
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
      <%!-- TWO EDGES IN HERE, THE SAME TWO THE PAGE HAS. The mark and the
           HEADINGS sit on --list-pad, because they are words and words step one
           in. The CONTENT — cells, doors, fields, the foot — begins at the
           rail, because that is where a fill begins and it is the same edge the
           band's wash and the trailing boxes take on the page behind.

           Forcing all of it onto one edge was the mistake: it made the panel
           read as an indented column floating inside the app rather than as the
           app's own surface, and it is not what the page it covers does. --%>
      <div class="fab-rooms rail relative flex h-full flex-col pt-(--head-top) pb-(--fab-foot)">
        <%!-- THE MARK COMES WITH YOU. The panel covers the page — masthead and
             all — and a room with nothing of the app at the top of it is a
             screen you could have arrived at from anywhere. It sits on the same
             --list-pad every word does, and the hook replays its entrance each
             time a room opens, so the eyes are drawn on rather than simply
             being there. That replay is the reference's one gesture kept whole:
             the head answering the door. --%>
        <div class="fab-head px-(--list-pad) pb-10">
          <.head class="h-7 text-primary-600 dark:text-primary-500" />
        </div>

        <%!-- ── THE LAUNCHER ───────────────────────────────────────────────
             Every door the app has, as a grid of squares. Squares because
             everything here is square; a wash rather than an outline because
             that is what a pressable box looks like on this surface; and the
             label under each in the same small tracked type the counts use.

             The reference drew these as circles with ring icons in stroke
             weight — a different vocabulary entirely, and one that would have
             read as somebody else's app dropped into this one. --%>
        <div
          data-panel-body="launcher"
          class="fab-body min-h-0 flex-1 overflow-y-auto"
          hidden
        >
          <p class={[heading_cls(), "px-(--list-pad)"]}>
            {(@current_person && String.upcase(@current_person.name)) || "NOT CHECKED IN"}
          </p>

          <%!-- THE REFERENCE'S CELLS, TAKEN AS FOUND. Same size, same neutral
               wash, same stroke icons, same wide-tracked label underneath. The
               only change is the corner radius, which is gone.

               They are NOT rebuilt in this app's own marks, and that was the
               mistake worth naming: a launcher is a place you arrive at from
               anywhere, and its cells were already doing their job. --%>
          <div class="mt-8 flex flex-wrap gap-x-10 gap-y-12">
            <.cell name="passport" label="Passport">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15 9h3.75M15 12h3.75M15 15h3.75M4.5 19.5h15a2.25 2.25 0 0 0 2.25-2.25V6.75A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25v10.5a2.25 2.25 0 0 0 2.25 2.25Zm6-10.125a1.875 1.875 0 1 1-3.75 0 1.875 1.875 0 0 1 3.75 0Zm1.294 6.336a6.721 6.721 0 0 1-3.17.789 6.721 6.721 0 0 1-3.168-.789 3.376 3.376 0 0 1 6.338 0Z"
              />
            </.cell>

            <.cell name="scoping" label="Scoping" badge={@unread}>
              <%!-- two interlocked rings — a mutual tie --%>
              <circle cx="8.5" cy="12" r="6" />
              <circle cx="15.5" cy="12" r="6" />
            </.cell>
          </div>
        </div>

        <%!-- ── THE PASSPORT ───────────────────────────────────────────────
             TWO DOORS, FULL WIDTH, and nothing else on the screen. There is
             exactly one question here — have you been before? — and a door for
             each answer is the whole of it.

             REQUEST LEADS because this app is for people who do not have a
             passport yet; check-in is the quieter of the two and wears the
             neutral wash to say so. Square-cornered, like everything else. --%>
        <div
          data-panel-body="passport"
          class="fab-body min-h-0 flex-1 overflow-y-auto"
          hidden
        >
          <.room_title>PASSPORT</.room_title>

          <%!-- A LIVEVIEW OF ITS OWN, nested. The passport is five steps of
               form state — a name, three words, a code, a country — and none of
               it is the surface's business; IndexLive's own moduledoc says that
               file is about the surface and nothing else. The registry knows
               only that there is a room called "passport"; what happens inside
               it is somebody else's process. --%>
          <div class="mt-8 w-(--list-w) max-w-full">
            {live_render(@socket, PeoplemediaWeb.PassportLive.Panel,
              id: "passport-panel",
              session: %{}
            )}
          </div>
        </div>

        <div
          data-panel-body="scoping"
          class="fab-body min-h-0 flex-1 overflow-y-auto"
          hidden
        >
          <.room_title>SCOPING</.room_title>
          <p class="mt-6 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            SWIPE A NAME TO SCOPE THEM
          </p>
        </div>
      </div>
    </div>
    """
  end

  # THE REFERENCE'S LAUNCHER CELL, kept whole: a 4.5rem square of neutral wash
  # with a stroke icon in it and a wide-tracked word underneath. Flattened, and
  # given the dark twin this app requires of every colour — nothing else moved.
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
        "fab-cell relative flex h-[4.5rem] w-[4.5rem] items-center justify-center transition",
        "bg-neutral-100 text-neutral-600 group-hover:bg-neutral-200 group-hover:text-neutral-800",
        "group-active:scale-95",
        "dark:bg-neutral-800 dark:text-neutral-300 dark:group-hover:bg-neutral-700",
        "dark:group-hover:text-neutral-100"
      ]}>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke-width="1.5"
          stroke="currentColor"
          class="h-7 w-7"
          aria-hidden="true"
        >
          {render_slot(@inner_block)}
        </svg>
        <span
          :if={@badge > 0}
          class="fab-badge absolute top-0 right-0 flex min-w-5 -translate-y-1/3 translate-x-1/3 items-center justify-center bg-primary-600 px-1 text-(length:--text-xs) text-primary-50 dark:bg-primary-500"
        >
          {(@badge > 9 && "9+") || @badge}
        </span>
      </span>
      <span class="text-(length:--text-xs) font-semibold uppercase tracking-[0.2em] text-neutral-500 dark:text-neutral-400">
        {@label}
      </span>
    </button>
    """
  end

  @doc """
  A DOOR: full width, a band tall, one word across it. Public because the
  passport flow's forward buttons are the same object — a step that moves you on
  is a door like any other, and two nearly-identical buttons would drift.
  """
  attr :name, :string, default: nil
  attr :tone, :atom, values: [:primary, :quiet], default: :quiet
  attr :rest, :global, include: ~w(type form disabled)
  slot :inner_block, required: true

  def door(assigns) do
    ~H"""
    <button
      data-panel-open={@name}
      {@rest}
      class={[
        "flex h-(--band-h) w-full cursor-pointer items-center justify-center",
        "text-(length:--sub-type) font-bold tracking-[0.25em] transition-colors outline-none",
        "focus-visible:ring-2 focus-visible:ring-primary-500/40",
        "disabled:cursor-not-allowed disabled:opacity-40",
        (@tone == :primary &&
           "bg-primary-500 text-primary-50 hover:bg-primary-600 dark:bg-primary-600 dark:hover:bg-primary-500") ||
          "bg-neutral-400/15 text-neutral-600 hover:bg-neutral-400/25 dark:bg-neutral-300/15 dark:text-neutral-300 dark:hover:bg-neutral-300/25"
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "The panel's heading voice — the same small tracked line the list's captions use."
  def heading_cls,
    do: "text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500"

  slot :inner_block, required: true

  defp room_title(assigns) do
    ~H"""
    <p class="px-(--list-pad) text-(length:--count-type) leading-none font-bold tracking-(--row-track) text-light-900 dark:text-dark-100">
      {render_slot(@inner_block)}
    </p>
    """
  end
end
