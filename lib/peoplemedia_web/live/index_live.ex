defmodule PeoplemediaWeb.IndexLive do
  @moduledoc """
  The people, the letters between them, and who is on the line right now.

  This is the same surface HomeLive carries, with the same behaviour and the
  same hooks — the difference is entirely in how it is MEASURED. HomeLive grew
  by accretion: a `max-w-6xl` on one box, a `w-[32rem]` on another, `px-4` on
  the container, `px-[1.95rem]` on the rows, `px-1` on the tags, and a bar sized
  `calc(min(100vw,72rem)-2rem)` to escape a parent narrower than itself. Five
  left edges, and a mark that had left all of them for the viewport edge.

  Here there is ONE bound and ONE rail, declared in app.css under "THE APP
  SHELL" and worn by every band of the page:

      .rail  →  max-width: --app-max, centred, --app-gutter either side

  THERE ARE EXACTLY TWO LEFT EDGES, and knowing which is which is the whole
  design:

    THE RAIL is STRUCTURE — the app's outer bound, which nothing crosses. It is
    where a FILL begins (the band's wash) and where a trailing box ENDS (the
    frame, the counts). No word sits on it.

    `--list-pad` is TEXT, one step in. Every word on the surface starts here:
    the mark, the line, the row labels, the band's own label. Rows and the band
    sharing it is what keeps a row's label exactly on top of the band's as it
    passes through, and the mark and the line joining them is what stops the
    app's furniture reading as pressed flat against the bound.

    A ROW NOW LEADS WITH A MARK, so its NAME starts one mark-width past
    `--list-pad` while the mark itself starts on it. That is not a third edge —
    it is one edge with two columns standing on it, and the band's empty dots
    sit in the mark's column because they are what a mark would arrive in.

    THE COLUMN IS ONLY RESERVED WHERE A MARK COULD GO. Every people row keeps
    it whether or not it has a letter, because the SCOPED and UNSCOPED lists
    share one scroller and a name that shifted sideways when you switched
    between them would make the two look like different columns. The picked
    header does NOT keep it: nothing can ever appear there, and an invisible
    thing that still takes room is the worst of both — it cannot be read and it
    cannot be ignored. Its words start on `--list-pad` like the dots do.

  So the split is not page-versus-list, it is structure-versus-words — which is
  why one number governs every text on the page and moving it moves them
  together.

  The two lenses belong to NEITHER level, because they are not the page's
  furniture and not a heading for the list — they are the SELECTION BOX's own
  controls. So they hang off the box: immediately under the band, ending on its
  right edge. Right is the only side that works, since everything below the band
  is live scrolling list and row labels are short and left-aligned, leaving that
  strip reliably clear.

  Collapsing those two into one was the earlier mistake in both directions: the
  old surface gave the MARK the list's inset (making it look like a list
  heading), and the first cut of this one took the inset off the ROWS (flattening
  them against the page edge). They are different things and are now measured
  separately. Nothing can reach the viewport either way, because the rail is the
  outer bound and the list lives inside it.

  The data lives in `Peoplemedia.Directory`, so this file is about the surface
  and nothing else.
  """
  use PeoplemediaWeb, :live_view

  alias Peoplemedia.Directory

  @impl true
  def mount(_params, _session, socket) do
    scopes = Directory.scopes()

    {:ok,
     socket
     |> assign(scopes: scopes, unscopes: Directory.unscopes(), countries: Directory.countries())
     |> assign(list_mode: :people, scope: "SCOPED", location: "Finland")
     |> assign(selected: nil, mode: :list)
     # THE FAB PANEL asks two things of the server: who is signed in, so the
     # launcher knows whether to offer a passport or a way to get one, and how
     # much is waiting, for the badge. Both are assigns rather than hook state
     # because both are facts the process owns.
     |> assign(unread: unread_for(socket.assigns[:current_person]))
     |> assign(live: Enum.filter(scopes, &(&1.state == "live")))
     |> put_list()
     |> put_current()}
  end

  # Nobody signed in has nothing waiting — and asking the database on behalf of
  # a visitor would be a query with no subject.
  defp unread_for(nil), do: 0
  defp unread_for(person), do: Peoplemedia.Notifications.unread_count(person.id)

  # ── STATE ───────────────────────────────────────────────────────────────────
  # The hook owns the scroll and therefore decides WHO is in the band; it reports
  # the answer here, because the panel is real content about a real person and
  # the process holding the data has to know which.
  @impl true
  def handle_event("select", %{"index" => index}, socket) do
    {:noreply, socket |> assign(selected: index) |> put_current()}
  end

  def handle_event("deselect", _params, socket) do
    # There is no such thing as an open view of nobody.
    {:noreply, socket |> assign(selected: nil, mode: :list) |> put_current()}
  end

  # Picking the band means different things over different lists. Over people it
  # opens the panel; over places there is no panel — the country simply becomes
  # the location tag's state. Nothing selected, nothing to pick.
  def handle_event("toggle_open", _params, socket) do
    case {socket.assigns.list_mode, socket.assigns.selected, socket.assigns.mode} do
      {_, nil, _} ->
        {:noreply, socket}

      # Over a place the band only SELECTS. Committing belongs to the counts,
      # because pressing one also says WHICH population you want, and a band
      # press could not answer that second question.
      {:location, _, _} ->
        {:noreply, socket}

      {:people, _, :open} ->
        {:noreply, assign(socket, mode: :list)}

      {:people, _, :list} ->
        {:noreply, assign(socket, mode: :open)}
    end
  end

  # ── THE TWO BOXES ───────────────────────────────────────────────────────────
  # THE HEAD OF THE LIST IS TWO SWITCHES, and each one flips a different axis of
  # the same question — WHERE, and WHICH OF THEM:
  #
  #   THE PLACE BOX toggles what the list HOLDS: people, or the roll of places
  #   to pick from. Pressing it in people mode opens the world; pressing it in
  #   the world COMMITS whatever has settled in the band and comes back.
  #
  #   THE POPULATION BOX toggles WHO of that place: the ones you hold, or the
  #   rest. It always lands on people, from either mode.
  #
  # WHY A TOGGLE AND NOT A PAIR. There were two count boxes before, off to the
  # right, and they were two doors into the same room — press SCOPES or press
  # UNSCOPES. But you are only ever in one of those populations at a time, and a
  # control that shows you the state you are NOT in is a control you have to
  # read before you can use. One box showing where you ARE, that swaps when
  # pressed, is the same two doors with the answer already given.
  def handle_event("place_box", _params, %{assigns: %{list_mode: :people}} = socket) do
    {:noreply, socket |> assign(list_mode: :location) |> reset_list()}
  end

  # COMMITTING IS WHAT THE BOX DOES ON THE WAY BACK. The band updates this box
  # as countries pass through it, but it changes nothing until pressed — you can
  # scroll the whole world and leave with the place you came in with.
  def handle_event("place_box", _params, socket) do
    {:noreply,
     socket
     |> assign(list_mode: :people, location: socket.assigns.box_place)
     |> reset_list()}
  end

  # AND IT COMMITS THE PLACE TOO when pressed from the world, which is the old
  # counts' behaviour kept whole: pressing a population under a country was
  # always an answer to both halves at once. Leaving the picker by this door
  # without taking the country you were looking at would be a door that undoes
  # what you just did.
  def handle_event("scope_box", _params, socket) do
    {:noreply,
     socket
     |> assign(
       list_mode: :people,
       location: socket.assigns.box_place,
       scope: other_scope(socket.assigns.scope)
     )
     |> reset_list()}
  end

  # THE WAY OUT THAT CHANGES NOTHING. Both boxes commit something, and the roll
  # of places has no empty state to escape to — the band always has a country in
  # it or reads WORLD, and WORLD is itself a choice. So leaving without choosing
  # needs a control of its own, or the only exit from the picker is a decision.
  def handle_event("cancel_place", _params, socket) do
    {:noreply, socket |> assign(list_mode: :people) |> reset_list()}
  end

  defp other_scope("SCOPED"), do: "UNSCOPED"
  defp other_scope(_unscoped), do: "SCOPED"

  # ── WHICH BOX IS LIT ────────────────────────────────────────────────────────
  # EXACTLY ONE AT A TIME, and it is whichever the list is currently obeying —
  # the place box over the roll of places, the population box over people.
  #
  # They are not equals sitting side by side. A population is READ OUT OF a
  # place: the count in the second box is the first box's own figure, and over
  # the roll of places it changes under your eye as countries pass through the
  # band. Lighting both would claim two things are being chosen when only one
  # is, and lighting the one whose value is being driven by the other is a box
  # lying about who is in charge.
  #
  # Written as two functions rather than inline, because the pair has to stay
  # identical across both boxes — a wash that is a shade off between them reads
  # as a bug rather than as a state. They take a BOOLEAN rather than assigns, so
  # the caller still names the assign it depends on and change tracking holds.
  defp box_wash(true),
    do:
      "bg-primary-600/15 hover:bg-primary-600/25 dark:bg-primary-500/20 dark:hover:bg-primary-500/30"

  defp box_wash(false),
    do:
      "bg-neutral-400/10 hover:bg-neutral-400/20 dark:bg-neutral-300/15 dark:hover:bg-neutral-300/25"

  defp box_ink(true), do: "text-primary-600 dark:text-primary-500"
  defp box_ink(false), do: "text-neutral-500 dark:text-neutral-400"

  # Swapping what the list holds makes the old index meaningless — it now points
  # at a different person, or at a country.
  defp reset_list(socket) do
    socket |> assign(selected: nil, mode: :list) |> put_list() |> put_current()
  end

  # ONE SCROLLER, THREE POSSIBLE CONTENTS, chosen by the two tags above it.
  defp current_list(%{list_mode: :location} = assigns), do: assigns.countries
  defp current_list(%{scope: "UNSCOPED"} = assigns), do: assigns.unscopes
  defp current_list(assigns), do: assigns.scopes

  # Stored rather than read through a function in the markup, which would switch
  # LiveView's change tracking off for the whole block.
  defp put_list(socket), do: assign(socket, :list, current_list(socket.assigns))

  # WHAT THE TWO BOXES SAY rides with the selection, because over the roll of
  # places the place box is showing the band's own answer — it follows the
  # country under the band without committing to it. In people mode there is
  # nothing to follow and it shows the place you committed to last.
  #
  # WORLD IS WHAT AN EMPTY BAND MEANS. The roll opens unselected, so the first
  # thing the box says on entering the picker is WORLD — which is both honest
  # (no country is chosen) and useful (pressing it takes everywhere).
  defp put_current(socket) do
    socket =
      assign(
        socket,
        :current,
        socket.assigns.selected && Enum.at(socket.assigns.list, socket.assigns.selected)
      )

    place =
      case socket.assigns do
        %{list_mode: :location, current: current} -> (current && current.name) || "WORLD"
        %{location: location} -> location
      end

    assign(socket, box_place: place, box_counts: Directory.population_of(place))
  end

  # ── THE SURFACE ─────────────────────────────────────────────────────────────
  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="scopes"
      class={[
        "app-root fixed inset-0 z-0 bg-light-50 font-mono dark:bg-dark-950",
        @mode == :open && "is-open"
      ]}
    >
      <%!-- ── THE APP LINE ─────────────────────────────────────────────────────
           The mark belongs to the APP, not to the list, so it takes its position
           from the rail like every other band of the page and from nothing else.
           It is absolute so it cannot push the body down and move the band with
           it — the band's placement is the one piece of geometry this screen is
           built on — but it wears the same .rail inside, which is what puts it
           on the same left edge as the line, the tags and the rows below.

           A BUTTON, not a link: home is this page, so the click had nothing to
           point at. It flips the theme and replays its own entrance doing it, so
           the thing you pressed is the thing that answers.

           THE MARK STANDS ALONE HERE. It wore a full-width bar for a while —
           lead, eyes, tail, all at the eyes' own height — and that geometry is
           still in app.css under THE APP RULE, still shown on /logo, and still
           two spans away from coming back. What decided against it is not how it
           looked: a bar is a LAYOUT, and a logo has to survive being cropped
           square, shrunk to a favicon and dropped on someone else's surface,
           none of which a page-width rule can do. --%>
      <header class="app-head pointer-events-none absolute inset-x-0 top-(--head-top) z-30">
        <div class="rail">
          <button
            id="logo"
            type="button"
            phx-hook="Head"
            class="pointer-events-auto inline-block cursor-pointer px-(--list-pad) outline-none focus-visible:ring-2 focus-visible:ring-primary-500/40"
            aria-label="Switch theme"
          >
            <.head class="h-7 text-primary-600 dark:text-primary-500" />
          </button>
        </div>
      </header>

      <%!-- ── THE ACT ──────────────────────────────────────────────────────────
           WRITING IS THE ONE THING YOU DO HERE. Everything else on this surface
           is looking: scrolling names, settling one in the band, opening what
           has passed between you. There is exactly one act, and until now there
           was nowhere to perform it.

           IT IS THE MASTHEAD'S OPPOSITE NUMBER, and built the same way: fixed,
           inset-x-0, one .rail inside, the control opting back into pointer
           events. So it lands on the app's own left edge without measuring
           anything — the same edge the mark takes at the top and the band's
           wash takes in the middle — and it cannot drift when the rail does.

           ON THE RAIL, NOT ON --list-pad, because it is a FILL and not a word.
           That is the whole of the two-edge rule in this file: the mark and the
           strapline are words and step one in; the band's wash, the trailing
           boxes and this begin at the bound. Its left edge and the band's are
           the same line.

           IT TAKES --act-h, NOT --band-h. It wore the band's height for a
           while, on the argument that everything square here should rhyme — but
           a rhyme needs two things near enough to hear together, and this sits
           alone in the opposite corner with nothing beside it to be measured
           against. At the band's height it read as a fourth trailing box that
           had wandered off. Its size is set by its job instead: a target you
           press. No brackets either: brackets on this surface mean AIMING, and
           this is not aimed at anything — it is where you start something.

           SOLID, AND THE ONLY SOLID THING HERE. Every other box on this surface
           is a WASH — a state you are in, drawn faintly because you are looking
           through it at something else. This is not a state, it is the one ACT,
           and the single control that answers to neither the band nor the list.
           So the fill and the mark trade places: terracotta to the ground, the
           mark cut out of it pale. Nothing else on the page does that, which is
           why it reads from the corner of the eye without being large.

           A STEP OFF THE FULL STRENGTH, IN BOTH DIRECTIONS. Solid terracotta at
           600 was the loudest thing on a page whose subject is a list of names,
           and being the only solid thing already gives it all the separation it
           needs. So it steps LIGHTER on cream (500) and DARKER on black (600) —
           the same ramp read from opposite ends, because what reduces weight on
           one page increases it on the other. Hover restores the step, so
           pressing still has somewhere to go.

           THE PLUS IS THIN. It began as the voice bar crossed with itself — the
           literal 16x6 rectangle every kind mark is cut from — and that was too
           good an idea to be true at this size: bars a quarter of the box thick,
           cut pale out of solid colour, made a slab rather than a mark. Thinned
           to 3.5 it is no longer that same rectangle, and the honest reading is
           the simpler one: a plus, drawn square-ended out of two bars, in a
           surface that draws everything out of square-ended bars.

           IT GOES WITH THE FURNITURE when the panel opens: a floating action
           hanging over a conversation you have opened is an action pointed at
           nothing.

           NO HANDLER YET, and that is deliberate rather than unfinished. There
           is no composer to send you to and no spine behind it — this app is
           the surface being designed before the thing it stands on, the same
           way `Directory` is fixtures and `/recorder` records nothing. Wire the
           phx-click the day there is somewhere for it to go. --%>
      <%!-- z-50, ABOVE the panel it controls. The act is the only way out of an
           open room, and the panel's ground is opaque — at z-30 the thing you
           press to close it was painted over by the thing it closes. --%>
      <div class="app-foot pointer-events-none fixed inset-x-0 bottom-(--foot-bottom) z-50">
        <div class="rail">
          <button
            id="act"
            type="button"
            aria-label="Open the launcher"
            aria-expanded="false"
            class={[
              "pointer-events-auto relative flex size-(--act-h) cursor-pointer items-center justify-center",
              "bg-primary-500 text-primary-50 transition-colors outline-none hover:bg-primary-600",
              "focus-visible:ring-2 focus-visible:ring-primary-500/40 focus-visible:ring-offset-2",
              "focus-visible:ring-offset-light-50 dark:focus-visible:ring-offset-dark-950",
              "dark:bg-primary-600 dark:hover:bg-primary-500"
            ]}
          >
            <%!-- THE PLUS AND THE CROSS ARE ONE MARK. Closing does not swap
                 in a different drawing; it turns this one 45 degrees, and
                 watching it turn is what says the cross you close with is the
                 plus you opened with. --%>
            <svg
              viewBox="0 0 24 24"
              class="act-mark absolute h-1/2 w-1/2"
              fill="currentColor"
              aria-hidden="true"
            >
              <rect x="4" y="10.25" width="16" height="3.5" />
              <rect x="10.25" y="4" width="3.5" height="16" />
            </svg>
            <%!-- Inside a room the act steps BACK to the launcher rather than
                 closing the app's front door, so it says so. The same stem and
                 chevron the flow arrows are drawn from, pointing left. --%>
            <svg
              viewBox="0 0 24 24"
              class="act-back absolute h-1/2 w-1/2"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="butt"
              stroke-linejoin="miter"
              aria-hidden="true"
            >
              <path d="M20 12H5" />
              <path d="M11.5 5.5 5 12l6.5 6.5" />
            </svg>
          </button>
        </div>
      </div>

      <.fab_panel socket={@socket} current_person={@current_person} unread={@unread} />

      <div class="rail flex h-screen flex-col pt-(--body-top)">
        <%!-- THE LINE, on the content edge with the mark above it and the names
             below. Every WORD on this surface now starts here; the bare rail is
             left to structure — where a fill begins and where a trailing box
             ends. Two jobs, cleanly split. --%>
        <%!-- THE PAIRING IS THE WHOLE OF IT, and it was once a bug worth
             remembering: this read `text-neutral-300 dark:text-neutral-200` —
             one step LIGHTER in dark, where every other line in this file steps
             DARKER. On a cream page #b0b0b0 is a whisper; on black, #d1d1d1 is
             nearly 14:1, so the same strapline whispered in one theme and
             shouted in the other.

             HALF A STEP QUIETER, BOTH WAYS — 300/700 to 250/750. This line is
             the only thing on the page that says nothing about the list: it is
             a standing sentence, read once, and after that it is furniture. At
             300 on cream it still caught the eye on every visit, which for a
             line you have already read is a small tax charged over and over.
             A FULL step (200/800) was too far the other way and lost it. The
             two half-steps are declared in app.css beside the 150 that was
             already there, and they move together or the two themes stop
             meaning the same thing — which is exactly how this went wrong the
             first time. --%>
        <p class="lede px-(--list-pad) text-(length:--row-type) tracking-[0.15em] text-neutral-250 dark:text-neutral-750">
          SO YOU DON'T DO LIFE ALONE
        </p>

        <%!-- THE STAGE. This box spans the RAIL, not the list column, and that
             is the fix for the old surface's worst joint: the bar used to live
             inside a 32rem parent while being wider than it, so its width was
             written as calc(min(100vw,72rem)-2rem) — the page's measure spelled
             out a second time, in a second place, free to disagree. Here the bar
             is simply inset-x-0 of a box that already IS the rail, and the list
             column is a child of it. One measure, stated once.

             Its height comes from the scroller inside it (the bar is absolute
             and adds none), which is what lets the bar's top:34% and the band
             the hook measures at 34% of the scroller be the same line. --%>
        <div class={["stage-box relative mt-12 min-h-0 w-full flex-1", @mode == :open && "list-away"]}>
          <%!-- phx-update="ignore": the hook marks the focused row with a class
               and a patch must never wipe it. THE ID CARRIES THE MODE, because
               on an ignored element a new identity is the only way to swap the
               rows underneath — that is what lets three lists share one
               scroller and one band. Anything keyed on this element in CSS must
               therefore use the CLASS, never the id. --%>
          <%!-- THE SCROLLER IS A DIRECT SIBLING OF THE BAR, and must stay one.
               The rules that reveal the "--" placeholder and the FRAME are
               written `.scopes-scroll.has-selection ~ .bar .frame` — the hook
               owns the scroller (it is the one element LiveView will not touch)
               and marks the selection there, and the bar reads it across. Wrap
               this in a column div for tidiness and the `~` stops matching: the
               frame silently never appears. The column width lives on the
               scroller itself for exactly that reason. --%>
          <div
            id={"scopes-scroll-#{@list_mode}-#{@scope}"}
            phx-hook="Scopes"
            phx-update="ignore"
            class="scopes-scroll h-full w-(--list-w) overflow-y-auto overscroll-contain"
          >
            <%!-- Lead and trail are what let the first and last row REACH the
                   band. The lead is one row DEEPER than the band, so the list
                   opens with the band standing empty — the unselected state. --%>
            <ul>
              <%!-- The row carries its own frame as DATA, not markup: one
                     shared frame reads these on settle, so nineteen rows cost
                     nineteen attributes rather than nineteen media elements. A
                     country carries none — its answer is a headcount the server
                     renders, not a face. --%>
              <%!-- ── THE ROW IS THE PANEL'S ROW ────────────────────────────
                     One shape for a list item in this app, and the panel is
                     where it was worked out: a KIND MARK, then the name with
                     its age hung under it. What was here before was the name
                     alone, which is why the two lists read as unrelated
                     surfaces despite being the same gesture one level apart.

                     What the home row adds is the FLOW, on the right — the
                     panel does not need it because a thread is already sorted
                     by direction and time, and a list of nineteen threads is
                     not. See `letter_flow/1` for what the two arrows mean.

                     THE MARK COLUMN IS ON EVERY PEOPLE ROW, filled or not. A
                     stranger has no letters — a letter is written to a SCOPE,
                     not to a person — but their row still reserves the mark's
                     width, because the SCOPED and UNSCOPED lists share one
                     scroller and one band, and a name that jumps sideways when
                     you switch between them would make the two look like
                     different columns. A country gets no mark at all: that
                     list is a roll of places, it never opens a header, and
                     there is no name of a person for it to line up with. --%>
              <li
                :for={item <- @list}
                data-state={item[:state] || "present"}
                data-frame={item[:frame] || "empty"}
                data-media={item[:media]}
                class={
                  [
                    "scopes-item flex cursor-pointer items-center px-(--list-pad) whitespace-nowrap",
                    "text-(length:--row-type) tracking-(--row-track) text-light-900 dark:text-dark-100",
                    # A PLACE IS ONE LINE, so it gets a shorter row. --row-h is
                    # sized for a name with its age hung under it; a roll of
                    # countries has no age and no mark, and at the people row's
                    # height the words ended up further apart than the band they
                    # scroll through is tall — which reads as a list with gaps in
                    # it rather than as a list.
                    (@list_mode == :location && "h-(--place-h)") || "h-(--row-h)"
                  ]
                }
              >
                <%!-- items-start on the inner block, not on the row: the mark
                       belongs on the NAME's line and the age hangs below it, but
                       the block as a whole is centred in the row. Pinning the
                       row itself to the top would have tied the block's position
                       to a hard padding that has to be refound every time the
                       row height moves. --%>
                <div class="flex min-w-0 flex-1 items-start">
                  <.letter_glyph
                    :if={@list_mode == :people}
                    kind={item[:letter][:kind]}
                    lit={!!item[:letter][:unread]}
                    class={[
                      "mr-3 -mt-[0.125em] transition-colors duration-200",
                      (item[:letter][:unread] && "text-primary-600 dark:text-primary-500") ||
                        "text-neutral-400 dark:text-neutral-500"
                    ]}
                  />
                  <div class="min-w-0 flex-1 leading-tight">
                    <p class="scopes-line flex items-baseline">
                      {String.upcase(item[:label] || item[:name])}
                      <%!-- Their own name, quiet beside the label, arriving only
                             while the row is IN the band. It keeps its own muted
                             colour on purpose: the focused row turns terracotta,
                             and this staying grey is what stops the band reading
                             as two labels shouting. Only a scoped person has both
                             a label and a name — a stranger or a country is one
                             word. --%>
                      <span
                        :if={item[:label]}
                        class="scopes-name ml-3 text-neutral-400/70 opacity-0 transition-opacity duration-200 dark:text-neutral-500/70"
                      >
                        {item[:name]}
                      </span>
                    </p>
                    <%!-- WHEN THE LAST LETTER CAME, and nothing else.

                           GREY, NOT THE WARM RAMP. It used to be `light-500`,
                           which is not a neutral at all — the light ramp runs
                           cream to cocoa, so its middle is a muted terracotta,
                           and an age drawn in it read as a quiet version of the
                           colour this surface uses for ATTENTION. Every subtext
                           here is grey for that reason: terracotta has one job
                           and a timestamp is not it.

                           It stays grey through the focus too — the row turning
                           terracotta is about the NAME, and an age that lit with
                           it would make the band read as two things being
                           pointed at. --%>
                    <p
                      :if={item[:letter]}
                      class="scopes-when mt-1 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400/75 dark:text-neutral-500/80"
                    >
                      {item.letter.when}
                    </p>
                  </div>
                  <%!-- THE FLOW RIDES ON THE NAME'S LINE, top right, mirroring
                       the kind mark at top left — the row's two marks are one
                       pair and belong on one line, with the age hanging under
                       the name between them. Centred against the whole two-line
                       block it sat below both of them and read as a third thing
                       floating in the row rather than as the other half of what
                       the left mark says. --%>
                  <.letter_flow :if={item[:letter]} letter={item.letter} class="ml-4" />
                </div>
              </li>
            </ul>
          </div>

          <%!-- ── THE TRAILING BOXES ─────────────────────────────────────────
               THREE BOXES ON ONE LINE, and between them they answer every
               question this screen can be asked: WHERE you are, WHICH of that
               place's two populations you are looking at, and — when there is
               one — WHAT the person under the band is sending.

               THEY ANSWER THE BAND, which is why they sit level with it on the
               right rail and not at the head of the column. Everything below
               the band is live scrolling list; the strip beside it is the one
               place on this surface that is reliably clear, and a control that
               answers "which one" belongs across from the thing doing the
               choosing. Moving them to the top left emptied the right half of a
               wide screen for nothing and left the band answering to nobody.

               WHAT DID CHANGE is that there is now one cluster instead of three
               separately-placed things — a text lens at the top left, two count
               boxes on the right and only over places, a frame on the same edge
               and only over people. The first two boxes never leave now; the
               third arrives inside the cluster rather than somewhere else.

               SIDE BY SIDE AND FLUSH, in one row, with the frame last so it
               keeps the rail's right edge — the app's right bound, which
               nothing crosses.

               ONE OF THE TWO IS LIT AT A TIME, and it is whichever the list is
               currently obeying: the place box over the roll of places, the
               population box over people. They are not equals sitting side by
               side — a population is read out of a place, so lighting both
               would claim two things are being chosen when only one is.

               NO BRACKETS ON EITHER OF THEM. Brackets on this surface mean
               AIMING — they pick out one thing among several — and there is
               nothing here to pick out: each box shows the state it is in, and
               pressing it changes that state. Colour alone carries it. The
               frame keeps its brackets, because a frame genuinely is aimed: it
               is the answer to whichever row the band has settled on. --%>
          <div class="scope-boxes pointer-events-none z-20 flex items-center gap-3">
            <%!-- ONE: THE PLACE, and the switch between people and the world.
                 Over people it names where you are; over the roll of places it
                 follows the band, showing whatever country has scrolled into it
                 without committing to any of them, and reading WORLD while the
                 band stands empty.

                 SO PRESSING IT MEANS TWO THINGS, and they are the same thing
                 said from either side: from people it opens the world, and from
                 the world it takes whatever it is currently showing and comes
                 back. A box that displays a place and commits that place when
                 pressed needs no label explaining which. --%>
            <button
              type="button"
              phx-click="place_box"
              aria-pressed={to_string(@list_mode == :location)}
              class={[
                "list-place pointer-events-auto flex h-(--band-h) min-w-0 cursor-pointer items-center",
                "px-5 outline-none transition-colors focus-visible:underline",
                box_wash(@list_mode == :location)
              ]}
            >
              <%!-- The place takes the ROW's type, not the count's, and that is
                   what keeps this box the narrower of the two: a word set at a
                   number's size would make the smaller box the wider one, and
                   "PHILIPPINES" would run the three past the rail. --%>
              <span class={[
                "truncate text-(length:--row-type) leading-none tracking-(--row-track) transition-colors",
                box_ink(@list_mode == :location)
              ]}>
                {String.upcase(@box_place)}
              </span>
            </button>

            <%!-- TWO: WHICH OF THEM, as a toggle rather than a pair.

                 There were two count boxes before — SCOPES and UNSCOPES, side
                 by side, each a door into that population. But you are only ever
                 inside one of them, so half of that control was always showing
                 you where you are NOT, and you had to read both to find the one
                 that was lit. One box showing where you ARE, which swaps when
                 pressed, is the same two doors with the answer already given.

                 IT COMMITS THE PLACE TOO, when pressed from the roll of places.
                 That is the old counts' behaviour kept whole: pressing a
                 population under a country always answered both halves at once,
                 and a door that dropped the country you were looking at on the
                 way through would undo the thing you had just done.

                 ITS COUNT IS THE PLACE'S COUNT, which is the other half of why
                 only one of these two can be lit: this box is not a sibling of
                 the place box, it is READ OUT OF IT. Over the roll of places it
                 goes quiet and follows the band — the numbers keep changing
                 under your eye as countries pass through, and a lit box whose
                 value is being driven by something else is a box lying about
                 who is in charge. --%>
            <button
              type="button"
              phx-click="scope_box"
              aria-pressed={to_string(@list_mode == :people)}
              class={[
                "list-scope pointer-events-auto flex h-(--band-h) shrink-0 cursor-pointer items-baseline",
                "gap-2.5 px-5 outline-none transition-colors focus-visible:underline",
                box_wash(@list_mode == :people)
              ]}
            >
              <span class={[
                "text-(length:--count-type) leading-none font-bold tracking-[0.06em] transition-colors",
                box_ink(@list_mode == :people)
              ]}>
                {(@scope == "SCOPED" && @box_counts.scopes) || @box_counts.unscopes}
              </span>
              <span class={[
                "text-(length:--sub-type) tracking-(--sub-track) transition-colors",
                (@list_mode == :people && "text-primary-600/55 dark:text-primary-500/55") ||
                  "text-neutral-400 dark:text-neutral-500"
              ]}>
                {(@scope == "SCOPED" && "SCOPES") || "UNSCOPES"}
              </span>
            </button>

            <%!-- THREE: THE FRAME — what the settled person is sending, and the
                 reason this surface exists. It is the only box here that is an
                 ANSWER rather than a control, which is why it is the only one
                 that comes and goes and the only one wearing brackets.

                 phx-update="ignore" is load-bearing for the MEDIA, not the
                 styling — without it a patch strips the src the hook set and
                 stops a face mid-sentence. Its state is all in CLASSES for the
                 matching reason: on an ignored element LiveView still merges
                 data-* from the server's copy and deletes any the client added.
                 The frame is wholly client-owned, which is honest, since a
                 playing media element cannot be driven from the server. --%>
            <div
              :if={@list_mode == :people}
              id="frame"
              phx-update="ignore"
              role="button"
              tabindex="0"
              aria-label="Expand frame"
              class="frame is-empty pointer-events-auto relative flex size-(--band-h) shrink-0 cursor-pointer items-center justify-center p-2 opacity-0 transition-[opacity,width,height,padding] duration-300"
            >
              <%!-- The screen is inset from the frame so the brackets bracket the
                   picture rather than cropping it, and square on every corner —
                   a screen has corners, and rounding them makes it a widget. --%>
              <div class="frame-screen relative h-full w-full overflow-hidden bg-primary-600/15 dark:bg-primary-500/20">
                <video class="frame-video h-full w-full object-cover" playsinline preload="metadata">
                </video>
                <%!-- Sits ON the screen, covering it: after a clip ends the
                     screen is the only thing there, and a control tucked into
                     the corner of a 45px square is a target nobody can hit. --%>
                <button
                  type="button"
                  class="frame-restart absolute inset-0 hidden items-center justify-center bg-light-950/15 text-light-50 transition-colors hover:bg-light-950/30 dark:bg-dark-950/25 dark:hover:bg-dark-950/40"
                  aria-label="Play again"
                >
                  <%!-- A three-quarter arc with an arrowhead, which reads as
                       "again"; heroicons' closed two-arrow loop says "sync". --%>
                  <svg
                    viewBox="0 0 1024 1024"
                    fill="currentColor"
                    stroke="currentColor"
                    stroke-width="0"
                    aria-hidden="true"
                    class="size-4"
                  >
                    <path d="M909.1 209.3l-56.4 44.1C775.8 155.1 656.2 92 521.9 92 290 92 102.3 279.5 102 511.5 101.7 743.7 289.8 932 521.9 932c181.3 0 335.8-115 394.6-276.1 1.5-4.2-.7-8.9-4.9-10.3l-56.7-19.5a8 8 0 0 0-10.1 4.8c-1.8 5-3.8 10-5.9 14.9-17.3 41-42.1 77.8-73.7 109.4A344.77 344.77 0 0 1 655.9 829c-42.3 17.9-87.4 27-133.8 27-46.5 0-91.5-9.1-133.8-27A341.5 341.5 0 0 1 279 755.2a342.16 342.16 0 0 1-73.7-109.4c-17.9-42.4-27-87.4-27-133.9s9.1-91.5 27-133.9c17.3-41 42.1-77.8 73.7-109.4 31.6-31.6 68.4-56.4 109.3-73.8 42.3-17.9 87.4-27 133.8-27 46.5 0 91.5 9.1 133.8 27a341.5 341.5 0 0 1 109.3 73.8c9.9 9.9 19.2 20.4 27.8 31.4l-60.2 47a8 8 0 0 0 3 14.1l175.6 43c5 1.2 9.9-2.6 9.9-7.7l.8-180.9c-.1-6.6-7.8-10.3-13-6.2z" />
                  </svg>
                </button>
              </div>
              <%!-- No controls, so the UA never renders any — the screen is the
                   only thing a voice is allowed to look like. --%>
              <audio class="frame-audio" preload="none"></audio>
            </div>

            <%!-- THE WAY OUT THAT CHANGES NOTHING. Both boxes commit something
                 when pressed, and the roll of places has no neutral exit of its
                 own: the band either holds a country or reads WORLD, and WORLD
                 is a choice like any other. So leaving the picker without
                 deciding needs a control of its own, or every exit is a
                 decision — including the one you make by accident.

                 FAR FROM THE PAIR, on the column's own right edge, because its
                 whole purpose is to be pressed on purpose. Small, unfilled and
                 quiet: it is the least interesting thing here and should never
                 be the first thing found. --%>
            <button
              :if={@list_mode == :location}
              type="button"
              phx-click="cancel_place"
              aria-label="Leave the world without changing place"
              class="pointer-events-auto cursor-pointer self-start p-1 text-neutral-400/50 transition-colors outline-none hover:text-neutral-500 focus-visible:text-neutral-500 dark:text-neutral-500/60 dark:hover:text-neutral-400"
            >
              <svg
                viewBox="0 0 24 24"
                class="size-[1.15em]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.75"
                stroke-linecap="butt"
                aria-hidden="true"
              >
                <path d="m5 5 14 14M19 5 5 19" />
              </svg>
            </button>
          </div>

          <%!-- BAND AND FRAME ARE ONE ROW, so the two can never fall out of line.
               The band answers "which one", the frame answers "and what are they
               sending". Both appear only on a settled selection. --%>
          <div
            id="bar"
            phx-hook="Bar"
            class={[
              "bar pointer-events-none absolute inset-x-0 top-(--band-top) flex -translate-y-1/2 items-center",
              @mode == :open && "is-picked"
            ]}
          >
            <%!-- THE LEFT HALF IS THE HANDLE — pressing here picks the whole bar
                 up and carries it to the top; pressing the frame at the other
                 end only resizes the frame. Two targets, two jobs, one bar.

                 list-box is "a row, filled": the same column width and the same
                 --list-pad every row uses, so the band's label lands exactly on
                 top of the label of whichever row is passing through it. Its
                 WASH starts at the rail, because the box is a block in the
                 frame; its WORDS start at the list's own inset, because that is
                 where every row's words start. --%>
            <div
              phx-click="toggle_open"
              class={[
                "focus-box list-box pointer-events-auto relative flex h-(--band-h) shrink-0 items-center",
                "bg-primary-600/15 dark:bg-primary-500/20",
                @selected && "cursor-pointer"
              ]}
            >
              <%!-- ABSOLUTE, not merely transparent: in flow its width sat in
                   front of the header's label and pushed the text off the rail.
                   Invisible is not the same as absent.

                   IT STANDS IN THE MARK'S COLUMN, not the name's, because that
                   is the column a mark would arrive in. Which is why it does
                   not take the name's indent below.

                   DOTS, AND IT USED TO BE "--". Two dashes was the wrong
                   drawing for one blunt reason: THE MARK IS TWO DASHES. The
                   app's logo is a pair of thin closed eyes, and the voice glyph
                   is a single bar as wide as they span — so an empty band was
                   showing, in terracotta, at the head of the list, something
                   the eye reads as the logo appearing in the middle of the
                   page. A placeholder must not be a sign that already means
                   something else.

                   A ROW OF DOTS means what no other mark here means: WAITING.
                   It is an ellipsis, which is a well-worn way to say "nothing
                   yet, and something is expected" — exactly the empty band's
                   state — and it is the one shape in this vocabulary that is
                   neither a rectangle nor made of them, so it can never be
                   mistaken for a face, a voice, a letter or the mark. --%>
              <span class="focus-empty absolute text-(length:--row-type) tracking-(--row-track) text-primary-600 opacity-0 transition-opacity duration-200 dark:text-primary-500">
                ...
              </span>
              <%!-- The bar takes over the words only at the moment of the pick.
                   In the list what you read is the ROW's label showing through a
                   translucent band; handing over while the two are still exactly
                   on top of each other means there is nothing to see. Neutral,
                   not terracotta — once this is a header it is the label on what
                   is below it, and terracotta is this surface's word for "look
                   here".

                   IT STARTS ON --list-pad, WITH NO MARK COLUMN. It carried an
                   empty `letter_glyph` for a while, to keep the label from
                   jumping left by a mark's width at the instant of the swap —
                   and that is a real thing, but it is a quarter of a second of
                   flight paid for by a permanent indent. What you are left
                   looking at is a header whose text sits forty pixels in from
                   the edge of its own box with nothing in the gap. The rows
                   need that column because they have marks to put in it; a
                   header has none, so it does not get the column.

                   AN INVISIBLE THING THAT STILL TAKES ROOM IS THE WORST OF BOTH:
                   it cannot be read and it cannot be ignored. If a slot has
                   nothing to hold here, it should not be here — which is why
                   this is a removal rather than a `visibility: hidden`. --%>
              <span
                :if={@mode == :open && @current}
                class="focus-name flex min-w-0 flex-1 items-baseline overflow-hidden whitespace-nowrap text-(length:--row-type) tracking-(--row-track) text-light-900 dark:text-dark-100"
              >
                {String.upcase(@current[:label] || @current[:name])}
                <span
                  :if={@current[:label]}
                  class="ml-3 text-neutral-400/70 dark:text-neutral-500/70"
                >
                  {@current[:name]}
                </span>
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- ── THE PANEL ────────────────────────────────────────────────────────
           What opens under the header once a relationship is picked up. A
           SIBLING of the list rather than a child, and fixed rather than in
           flow, because the list must keep its geometry while hidden — the bar
           is positioned against the list's box, so a collapsing container would
           drag the header off its own line mid-flight.

           TWO VIEWS, ONE ROOM: LETTERS on the left is what has passed between
           you — held, finished, re-readable — and LIVE on the right is who is
           on the line right now. It wears the same .rail, so LETTERS lands on
           the very edge the mark, the line, the tags and the rows all use.

           IT USED TO SAY RECORD, and the word was wrong in a way that only
           showed once a third kind arrived. "Record" names the ACT OF
           CAPTURING, which a face and a voice share and words do not, so a
           typed letter could not be filed under it without the heading lying.
           A LETTER names what the thing IS rather than how it was made, and
           all three are letters: one carries a face, one carries a voice, one
           carries only itself. It is also written TO A SCOPE and not to a
           person — the scope is the relationship, and the relationship is what
           the correspondence belongs to. --%>
      <div
        :if={@mode == :open && @current}
        id="panel"
        class="panel fixed inset-x-0 top-(--panel-top) bottom-0 z-20"
      >
        <div class="rail h-full">
          <div class="panel-views flex h-full items-start gap-14 pt-8">
            <div
              id="panel-letters"
              phx-hook="SubPanel"
              class="panel-letters relative h-full w-full shrink-0 lg:w-(--list-w)"
            >
              <%!-- THE HANDLE, phone only. The letters list rides OVER the live
                   view there, so it needs somewhere to be taken hold of — and a
                   handle is also the only honest way to say "this moves", which
                   a panel that simply sits there does not. --%>
              <div class="sub-handle lg:hidden" aria-hidden="true"><span></span></div>
              <p class="absolute top-6 left-0 z-20 text-(length:--sub-type) tracking-[0.22em] text-neutral-400 dark:text-neutral-500">
                LETTERS
              </p>

              <%!-- THE BOX — the list's own selection box kept whole: the wash,
                   the brackets, the "--" for an empty band. What is different is
                   that its job is not delegated to a frame off to the side; the
                   box IS the player. A voice fills it as a bar, a face shows in
                   it. It sits BEHIND the rows (z-0 to their z-10) so the chosen
                   row's name reads over whatever is playing, and the brackets,
                   being at the corners, clear the words entirely. --%>
              <div
                id={"stage-#{@selected}"}
                phx-update="ignore"
                class="stage w-full px-(--list-pad) lg:w-(--list-w) pointer-events-none absolute top-[calc(var(--panel-row-h)*1.5)] left-0 z-0 flex h-(--panel-row-h) -translate-y-10 items-center overflow-hidden bg-primary-600/15 dark:bg-primary-500/20"
              >
                <video
                  class="stage-video absolute inset-0 h-full w-full object-cover"
                  playsinline
                  preload="metadata"
                >
                </video>
                <div class="stage-fill absolute inset-0"></div>
                <%!-- A voice's play effect: a translucent layer whose WIDTH is
                     the fraction played, so the box fills like a bar. --%>
                <div class="stage-progress absolute inset-y-0 left-0"></div>
                <%!-- The list's own empty mark, for the same reason and in the
                     same shape — see the band above. --%>
                <span class="focus-empty text-(length:--row-type) tracking-(--row-track) text-primary-600 opacity-0 transition-opacity duration-200 dark:text-primary-500">
                  ...
                </span>
                <audio class="stage-audio" preload="none"></audio>
              </div>

              <%!-- Lead and trail here are set by the hook, not the markup, so
                   the list rests unselected and every row can still reach the
                   band. --%>
              <div
                id={"panel-scroll-#{@selected}"}
                phx-hook="Panel"
                phx-update="ignore"
                class="panel-scroll relative z-10 h-full overflow-y-auto overscroll-contain"
              >
                <ul class="pt-[calc(34vh+4rem)] pb-[30vh]">
                  <li
                    :for={letter <- @current.letters}
                    data-kind={letter.kind}
                    data-media={letter.media}
                    class="panel-item flex h-(--panel-row-h) cursor-pointer items-start px-(--list-pad) whitespace-nowrap pt-[1.15rem] text-(length:--row-type) tracking-(--row-track) text-neutral-900 dark:text-neutral-100"
                  >
                    <%!-- The kind mark leads — two eyes for a face, one mouth for
                         a voice, the mouth struck through for a letter that is
                         only words — pinned to the TOP beside the name rather
                         than centred against the two-line block, so it reads on
                         the name's line and the age hangs below it. --%>
                    <.letter_glyph
                      kind={letter.kind}
                      class="mr-3 -mt-[0.125em] text-neutral-400 dark:text-neutral-500"
                    />
                    <div class="flex flex-col leading-tight">
                      <span>{letter.by}</span>
                      <span class="panel-when mt-1 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400/55 dark:text-neutral-500/60">
                        {letter.when}
                      </span>
                    </div>
                  </li>
                </ul>
              </div>
            </div>

            <%!-- THE ROOM. Everyone whose line is open, and ONE set of brackets
                 that glides between them to rest on whoever is speaking.
                 Attention in a real room is one thing that moves, not every face
                 outlined at once — which is what every call grid does. Hidden
                 below lg: there is no honest way to show a room in a column. --%>
            <div
              id="live-room"
              phx-hook="LiveRoom"
              phx-update="ignore"
              class="live-grid pointer-events-none min-w-0 flex-1 pt-6"
            >
              <p class="mb-5 flex items-center gap-3 text-(length:--sub-type) tracking-[0.22em] text-neutral-400 dark:text-neutral-500">
                LIVE <span class="text-neutral-300 dark:text-neutral-600">{length(@live)}</span>
                <%!-- THE PAGER, which the hook hides whenever there is only one
                     page — a control that can never do anything is furniture,
                     not an affordance. pointer-events-auto against the room's
                     none: the grid is a display, these two are the exception. --%>
                <span class="live-pager pointer-events-auto ml-auto flex items-center gap-2" hidden>
                  <button
                    type="button"
                    class="live-prev cursor-pointer px-1 transition-colors hover:text-neutral-500 disabled:cursor-default disabled:opacity-30 dark:hover:text-neutral-400"
                    aria-label="Previous page"
                  >
                    &lt;
                  </button>
                  <span class="live-page text-neutral-300 tabular-nums dark:text-neutral-600"></span>
                  <button
                    type="button"
                    class="live-next cursor-pointer px-1 transition-colors hover:text-neutral-500 disabled:cursor-default disabled:opacity-30 dark:hover:text-neutral-400"
                    aria-label="Next page"
                  >
                    &gt;
                  </button>
                </span>
              </p>
              <div class="relative grid grid-cols-3 gap-x-5 gap-y-4">
                <div
                  :for={{person, i} <- Enum.with_index(@live)}
                  class="live-cell"
                  data-speaks={to_string(person.frame != "empty")}
                  style={"--i: #{i}"}
                >
                  <div class={[
                    "live-frame is-live relative aspect-square w-full overflow-hidden",
                    "is-#{person.frame}"
                  ]}>
                    <video
                      :if={person.frame == "face"}
                      class="live-video absolute inset-0 h-full w-full object-cover"
                      src={person.media}
                      autoplay
                      muted
                      loop
                      playsinline
                    >
                    </video>
                    <div class="live-screen absolute inset-0"></div>
                  </div>
                  <span class="mt-2 block truncate text-sm tracking-[0.14em] text-neutral-500 dark:text-neutral-400">
                    {person.label || person.name}
                  </span>
                </div>
                <div class="live-reticle pointer-events-none absolute top-0 left-0"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
