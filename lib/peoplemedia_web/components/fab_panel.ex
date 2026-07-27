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
  attr :scope_target, :any, default: nil
  attr :scope_error, :any, default: nil
  attr :pending, :map, default: %{incoming: [], outgoing: []}

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

        <%!-- ── SCOPING ────────────────────────────────────────────────────
             THE REFERENCE'S SHAPE: sections that only exist when they have
             something in them, each row the other person's name over a line
             saying what is owed and by whom. Server-rendered from the durable
             `scoping` rows, so a reload cannot lose a handshake mid-flight. --%>
        <div data-panel-body="scoping" class="fab-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>SCOPING</.room_title>

          <p
            :if={@pending.incoming == [] and @pending.outgoing == []}
            class={[heading_cls(), "px-(--list-pad) pt-10"]}
          >
            NOTHING IN MOTION — SWIPE A NAME TO SCOPE THEM
          </p>

          <.section :if={@pending.incoming != []} title="INCOMING" count={length(@pending.incoming)}>
            <.pending_row :for={e <- @pending.incoming} entry={e} />
          </.section>

          <.section :if={@pending.outgoing != []} title="OUTGOING" count={length(@pending.outgoing)}>
            <.pending_row :for={e <- @pending.outgoing} entry={e} />
          </.section>
        </div>

        <%!-- ── ONE SCOPE ──────────────────────────────────────────────────
             Where the swipe lands. One question, because the answer IS the act:
             a scope with no name is not a weaker scope, it is a follow, and this
             app does not have those. --%>
        <div data-panel-body="scope" class="fab-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>{(@scope_target && String.upcase(@scope_target.name)) || "SCOPE"}</.room_title>

          <p
            :if={@scope_error}
            class={[heading_cls(), "px-(--list-pad) pt-6 text-primary-600 dark:text-primary-500"]}
          >
            {String.upcase(@scope_error)}
          </p>

          <form :if={@scope_target} phx-submit="scope_send" class="pt-6">
            <p class={[heading_cls(), "px-(--list-pad)"]}>WHAT DO YOU CALL THEM?</p>
            <input
              type="text"
              name="label"
              value=""
              placeholder="Mum"
              autocomplete="off"
              class="w-full bg-transparent pt-6 text-(length:--count-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
            />
            <p class={[heading_cls(), "px-(--list-pad) pt-3"]}>
              THEIRS TO ANSWER, AND THEIRS TO NAME YOU BACK
            </p>
            <div class="pt-10">
              <.door type="submit" tone={:primary}>SCOPE THEM</.door>
            </div>
          </form>

          <p :if={is_nil(@scope_target)} class={[heading_cls(), "px-(--list-pad) pt-10"]}>
            SWIPE A NAME IN THE LIST TO SCOPE THEM
          </p>
        </div>

        <%!-- ── WRITE ──────────────────────────────────────────────────────
             The one act this app is for. Text only for now: a voice and a face
             need a recorder and this needs none, and the write path is the same
             either way — so proving it with words proves it. --%>
        <div data-panel-body="write" class="fab-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>{(@scope_target && String.upcase(@scope_target.name)) || "WRITE"}</.room_title>

          <p
            :if={@scope_error}
            class={[heading_cls(), "px-(--list-pad) pt-6 text-primary-600 dark:text-primary-500"]}
          >
            {String.upcase(@scope_error)}
          </p>

          <form :if={@scope_target} phx-submit="write_letter" class="pt-6">
            <p class={[heading_cls(), "px-(--list-pad)"]}>A LETTER</p>
            <textarea
              name="body"
              rows="5"
              placeholder="Say something."
              class="w-full resize-none bg-transparent pt-6 text-(length:--row-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
            ></textarea>
            <div class="pt-6">
              <.door type="submit" tone={:primary}>SEND IT</.door>
            </div>
          </form>

          <p :if={is_nil(@scope_target)} class={[heading_cls(), "px-(--list-pad) pt-10"]}>
            SWIPE A NAME YOU HOLD TO WRITE TO THEM
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

  # A SECTION EXISTS ONLY WHEN IT HAS SOMETHING IN IT — the reference's rule, and
  # the reason this room never shows an empty heading over nothing.
  attr :title, :string, required: true
  attr :count, :integer, required: true
  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <div class="pt-10">
      <p class={[heading_cls(), "px-(--list-pad)"]}>{@title} · {@count}</p>
      <div class="pt-4">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  # ONE ROW PER HANDSHAKE: their name, and under it the line that says whose
  # move it is. The phases are the reference's, and the wording is the reference's
  # too — it is careful about which side is waiting, which is the only thing
  # anyone reads this list to find out.
  attr :entry, :map, required: true

  defp pending_row(assigns) do
    ~H"""
    <div class="px-(--list-pad) py-4">
      <span class="block truncate text-(length:--sub-type) font-semibold tracking-(--sub-track) text-neutral-600 dark:text-neutral-300">
        {(@entry.other && String.upcase(@entry.other.name)) || "SOMEONE"}
      </span>
      <span class="block truncate pt-1 text-(length:--sub-type) text-neutral-400 dark:text-neutral-500">
        {line_for(@entry)}
      </span>

      <%!-- WHOSE MOVE IT IS, AS SOMETHING TO PRESS. A request you can see but
           not answer is a notice, not a handshake — which is what this room was
           until these arrived.

           `respond` asks for a NAME as well as a yes, because round two is not
           merely consent: it is where you say what you call them, and that is a
           claim they should see before it stands. --%>
      <form
        :if={@entry.phase == "respond" and @entry.other}
        phx-submit="scope_back"
        class="flex items-end gap-3 pt-4"
      >
        <%!-- `other_id`, not `id`: a form field named "id" shadows the DOM id
             of the element carrying it, and LiveView says so. --%>
        <input type="hidden" name="other_id" value={@entry.other.id} />
        <input
          type="text"
          name="label"
          placeholder="what you call them"
          autocomplete="off"
          class="min-w-0 flex-1 bg-transparent text-(length:--row-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
        />
        <.answer type="submit" tone={:primary}>SCOPE BACK</.answer>
        <.answer type="button" phx-click="scope_reject" phx-value-id={@entry.other.id}>
          DECLINE
        </.answer>
      </form>

      <div :if={@entry.phase == "review" and @entry.other} class="flex gap-3 pt-4">
        <.answer type="button" tone={:primary} phx-click="scope_accept" phx-value-id={@entry.other.id}>
          ACCEPT
        </.answer>
        <.answer type="button" phx-click="scope_reject" phx-value-id={@entry.other.id}>
          DECLINE
        </.answer>
      </div>

      <div :if={@entry.phase == "waiting_back" and @entry.other} class="flex gap-3 pt-4">
        <.answer type="button" phx-click="scope_reject" phx-value-id={@entry.other.id}>
          CANCEL
        </.answer>
      </div>
    </div>
    """
  end

  # A small flat answer — the door's language at a row's scale. Not a door,
  # because a door is the width of the room and these come in pairs.
  attr :tone, :atom, values: [:primary, :quiet], default: :quiet
  attr :rest, :global, include: ~w(type form disabled)
  slot :inner_block, required: true

  defp answer(assigns) do
    ~H"""
    <button
      {@rest}
      class={[
        "shrink-0 cursor-pointer px-4 py-3 text-(length:--sub-type) tracking-(--sub-track)",
        "transition-colors outline-none",
        (@tone == :primary &&
           "bg-primary-600/15 text-primary-600 hover:bg-primary-600/25 dark:bg-primary-500/20 dark:text-primary-500 dark:hover:bg-primary-500/30") ||
          "bg-neutral-400/10 text-neutral-500 hover:bg-neutral-400/20 dark:bg-neutral-300/10 dark:text-neutral-400 dark:hover:bg-neutral-300/20"
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp line_for(%{phase: "respond", their_label: l}), do: "calls you “#{l}” — answer"
  defp line_for(%{phase: "review", their_label: l}), do: "scoped you back “#{l}” — finalise"

  defp line_for(%{phase: "waiting_accept", my_label: l}),
    do: "you answered “#{l}” · awaiting their yes"

  defp line_for(%{phase: "waiting_back", my_label: l}), do: "you call them “#{l}” · waiting"
  defp line_for(_), do: "in motion"

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
