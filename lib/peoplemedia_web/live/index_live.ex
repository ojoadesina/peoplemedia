defmodule PeoplemediaWeb.IndexLive do
  @moduledoc """
  The presence app, rebuilt on a layout system.

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
     |> assign(live: Enum.filter(scopes, &(&1.state == "live")))
     |> put_list()
     |> put_current()}
  end

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

  # ONE TAG, because it was always one thought. "SCOPED FINLAND" is a scope and
  # a place said together, and that pair is what you are actually looking at —
  # split across two buttons it read as two unrelated switches. Pressing it opens
  # the world, since changing either half of that sentence begins the same way.
  def handle_event("to_location", _params, socket) do
    {:noreply, socket |> assign(list_mode: :location) |> reset_list()}
  end

  # THE COUNTS ARE THE WAY BACK, and pressing one answers both halves of the
  # sentence at once: it commits the country settled in the band AND says which
  # of that country's two populations you meant. Which is why they are pressable
  # rather than decorative — "41 SCOPES" is not a fact about Nigeria, it is the
  # door to those 41 people.
  def handle_event("enter_people", %{"scope" => scope}, socket)
      when scope in ~w(SCOPED UNSCOPED) do
    location = (socket.assigns.current && socket.assigns.current.name) || socket.assigns.location

    {:noreply,
     socket
     |> assign(list_mode: :people, scope: scope, location: location)
     |> reset_list()}
  end

  # Swapping what the list holds makes the old index meaningless — it now points
  # at a different person, or at a country.
  defp reset_list(socket) do
    socket |> assign(selected: nil, mode: :list) |> put_list() |> put_current()
  end

  # ONE SCROLLER, THREE POSSIBLE CONTENTS, chosen by the two tags above it.
  defp current_list(%{list_mode: :location} = assigns), do: assigns.countries
  defp current_list(%{scope: "UNSCOPED"} = assigns), do: assigns.unscopes
  defp current_list(assigns), do: assigns.scopes

  # Both are stored rather than read through a function in the markup, which
  # would switch LiveView's change tracking off for the whole block.
  defp put_list(socket), do: assign(socket, :list, current_list(socket.assigns))

  defp put_current(socket) do
    assign(
      socket,
      :current,
      socket.assigns.selected && Enum.at(socket.assigns.list, socket.assigns.selected)
    )
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
           the thing you pressed is the thing that answers. --%>
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

      <div class="rail flex h-screen flex-col pt-(--body-top)">
        <%!-- THE LINE, on the content edge with the mark above it and the names
             below. Every WORD on this surface now starts here; the bare rail is
             left to structure — where a fill begins and where a trailing box
             ends. Two jobs, cleanly split. --%>
        <p class="lede px-(--list-pad) text-[clamp(var(--text-xl),0.85rem+0.38vw,var(--text-4xl))] tracking-[0.15em] text-neutral-300 dark:text-neutral-200">
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
              <li
                :for={item <- @list}
                data-state={item[:state] || "present"}
                data-frame={item[:frame] || "empty"}
                data-media={item[:media]}
                class="scopes-item flex h-(--row-h) cursor-pointer items-center px-(--list-pad) whitespace-nowrap text-[clamp(var(--text-xl),0.85rem+0.38vw,var(--text-4xl))] tracking-[0.14em] text-light-900 dark:text-dark-100"
              >
                <span>{item[:label] || item[:name]}</span>
                <%!-- Their own name, quiet beside the label, arriving only
                       while the row is IN the band. It keeps its own muted
                       colour on purpose: the focused row turns terracotta, and
                       this staying grey is what stops the band reading as two
                       labels shouting. Only a scoped person has both a label and
                       a name — a stranger or a country is one word. --%>
                <span
                  :if={item[:label]}
                  class="scopes-name ml-3 text-light-300 opacity-0 transition-opacity duration-200 dark:text-dark-600"
                >
                  {item[:name]}
                </span>
              </li>
            </ul>
          </div>

          <%!-- THE TWO LENSES, hung off the SELECTION BOX itself rather than
               floating somewhere near it. They sit immediately under the band
               and end on its right edge, so they read as that box's own
               controls — which is what they are: they decide what the box is
               choosing between.

               RIGHT-ALIGNED IS LOAD-BEARING, not a preference. Everything below
               the band is live scrolling list, and rows would slide straight
               through a label parked there. Row labels are short and left-
               aligned against --list-pad, so the band's far right is the one
               strip of that column reliably empty — putting the tags there is
               what lets them touch the box without ever colliding with it.

               Offset is the band's half-height plus a hair, so the two stay
               welded however --band-top moves.

               TEXT, NOT CHIPS. A filled box reads as a control you press once
               and are done with; these are a pair you live in, and the lit one
               is the one you are inside. Colour alone says so — PRIMARY for
               where you are, muted for where you are not — the language the
               focused row and the band already speak. The location lens wears
               its PLACE as its name: "LOCATION FINLAND" said it twice. --%>
          <div class="scope-tags pointer-events-none absolute top-[calc(var(--band-top)+2.25rem)] left-0 z-20 flex w-(--list-w) justify-end">
            <button
              type="button"
              phx-click="to_location"
              aria-pressed={to_string(@list_mode == :location)}
              class={[
                "pointer-events-auto cursor-pointer text-sm tracking-[0.22em] transition-colors outline-none focus-visible:underline",
                (@list_mode == :location && "text-primary-600 dark:text-primary-500") ||
                  "text-neutral-400 hover:text-neutral-500 dark:text-neutral-500 dark:hover:text-neutral-400"
              ]}
            >
              {@scope} {String.upcase(@location)}
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
                "focus-box list-box pointer-events-auto relative flex h-14 shrink-0 items-center",
                "bg-primary-600/15 dark:bg-primary-500/20",
                @selected && "cursor-pointer"
              ]}
            >
              <%!-- ABSOLUTE, not merely transparent: in flow its width sat in
                   front of the header's label and pushed the text off the rail.
                   Invisible is not the same as absent. --%>
              <span class="focus-empty absolute text-[clamp(var(--text-xl),0.85rem+0.38vw,var(--text-4xl))] tracking-[0.14em] text-primary-600 opacity-0 transition-opacity duration-200 dark:text-primary-500">
                --
              </span>
              <%!-- The bar takes over the words only at the moment of the pick.
                   In the list what you read is the ROW's label showing through a
                   translucent band; handing over while the two are still exactly
                   on top of each other means there is nothing to see. Neutral,
                   not terracotta — once this is a header it is the label on what
                   is below it, and terracotta is this surface's word for "look
                   here". --%>
              <span
                :if={@mode == :open && @current}
                class="focus-name flex min-w-0 flex-1 items-baseline overflow-hidden whitespace-nowrap text-[clamp(var(--text-xl),0.85rem+0.38vw,var(--text-4xl))] tracking-[0.14em] text-light-900 dark:text-dark-100"
              >
                {@current[:label] || @current[:name]}
                <span :if={@current[:label]} class="ml-3 text-light-500 dark:text-dark-500">
                  {@current[:name]}
                </span>
              </span>
            </div>
          </div>

          <%!-- THE FRAME — the box that shows what the settled person is
                 sending, and the reason this surface exists. ml-auto pins it to
                 the RAIL'S RIGHT EDGE, which is the app's right bound: anything
                 else that ever sits on the right of this line lands on the same
                 edge, and nothing can pass it.

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
            class="frame is-empty pointer-events-auto relative ml-auto flex size-[3.8rem] shrink-0 cursor-pointer items-center justify-center p-2 opacity-0 transition-[opacity,width,height,padding] duration-300"
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

          <%!-- THE HEADCOUNT, on the same right edge the frame holds. A place
                 in the band has no face and no voice — it has how many are
                 present there right now. Server-rendered rather than hook-owned,
                 because it is a number the process knows and not media the
                 client has to play. --%>
          <div
            :if={@list_mode == :location}
            class={[
              "counts relative ml-auto flex h-[3.8rem] shrink-0 items-center transition-opacity duration-300",
              (@current && "opacity-100") || "opacity-0"
            ]}
          >
            <%!-- TWO IDENTICAL BOXES, and that is the point. They are the same
                   kind of thing — a population of this place, and a door into it
                   — so making one bigger or colder would rank them, and they are
                   not ranked. The scoped box keeps the frame's footprint and the
                   frame's right edge, because in this mode it is what the band is
                   pointing at: a place answers with numbers where a person
                   answers with a face.

                   What tells them apart is the BRACKETS, which sit on whichever
                   population you are currently in. That is the same job brackets
                   do everywhere here — they do not decorate a box, they aim at
                   the chosen one — so nothing new has to be learned to read
                   which of the two you are looking through. --%>
            <button
              type="button"
              phx-click="enter_people"
              phx-value-scope="SCOPED"
              disabled={is_nil(@current)}
              class={[
                "count-pick count-box pointer-events-auto relative flex h-full cursor-pointer items-baseline gap-2 px-4 transition-colors",
                (@scope == "SCOPED" &&
                   "is-active bg-primary-600/15 hover:bg-primary-600/25 dark:bg-primary-500/20 dark:hover:bg-primary-500/30") ||
                  "bg-neutral-400/10 hover:bg-neutral-400/20 dark:bg-neutral-300/20 dark:hover:bg-neutral-300/30"
              ]}
            >
              <span class={[
                "text-[clamp(var(--text-2xl),0.9rem+0.5vw,var(--text-6xl))] leading-none tracking-[0.06em]",
                (@scope == "SCOPED" && "text-primary-600 dark:text-primary-500") ||
                  "text-neutral-500 dark:text-neutral-400"
              ]}>
                {@current && @current.scopes}
              </span>
              <span class={[
                "text-sm tracking-[0.18em]",
                (@scope == "SCOPED" && "text-primary-600/55 dark:text-primary-500/55") ||
                  "text-neutral-400 dark:text-neutral-500"
              ]}>
                SCOPES
              </span>
            </button>

            <%!-- Everyone else there, hung under it on the same right edge so
                   the two stack as one object. --%>
            <button
              type="button"
              phx-click="enter_people"
              phx-value-scope="UNSCOPED"
              disabled={is_nil(@current)}
              class={[
                "count-pick count-unscoped pointer-events-auto absolute top-full right-0 mt-4 flex h-[3.8rem] cursor-pointer items-baseline gap-2 px-4 transition-colors",
                (@scope == "UNSCOPED" &&
                   "is-active bg-primary-600/15 hover:bg-primary-600/25 dark:bg-primary-500/20 dark:hover:bg-primary-500/30") ||
                  "bg-neutral-400/10 hover:bg-neutral-400/20 dark:bg-neutral-300/20 dark:hover:bg-neutral-300/30"
              ]}
            >
              <span class={[
                "text-[clamp(var(--text-2xl),0.9rem+0.5vw,var(--text-6xl))] leading-none tracking-[0.06em]",
                (@scope == "UNSCOPED" && "text-primary-600 dark:text-primary-500") ||
                  "text-neutral-500 dark:text-neutral-400"
              ]}>
                {@current && @current.unscopes}
              </span>
              <span class={[
                "text-sm tracking-[0.18em]",
                (@scope == "UNSCOPED" && "text-primary-600/55 dark:text-primary-500/55") ||
                  "text-neutral-400 dark:text-neutral-500"
              ]}>
                UNSCOPES
              </span>
            </button>
          </div>
        </div>
      </div>

      <%!-- ── THE PANEL ────────────────────────────────────────────────────────
           What opens under the header once a relationship is picked up. A
           SIBLING of the list rather than a child, and fixed rather than in
           flow, because the list must keep its geometry while hidden — the bar
           is positioned against the list's box, so a collapsing container would
           drag the header off its own line mid-flight.

           TWO VIEWS, ONE ROOM: RECORD on the left is what this relationship
           LEFT — presences, held — and LIVE on the right is who is on the line
           right now. It wears the same .rail, so RECORD lands on the very edge
           the mark, the line, the tags and the rows all use. --%>
      <div
        :if={@mode == :open && @current}
        id="presence-panel"
        class="presence-panel fixed inset-x-0 top-(--panel-top) bottom-0 z-20"
      >
        <div class="rail h-full">
          <div class="panel-views flex h-full items-start gap-14 pt-8">
            <div
              id="record-view"
              phx-hook="SubPanel"
              class="record-view relative h-full w-full shrink-0 lg:w-(--list-w)"
            >
              <%!-- THE HANDLE, phone only. The record list rides OVER the live
                   view there, so it needs somewhere to be taken hold of — and a
                   handle is also the only honest way to say "this moves", which
                   a panel that simply sits there does not. --%>
              <div class="sub-handle lg:hidden" aria-hidden="true"><span></span></div>
              <p class="absolute top-6 left-0 z-20 text-sm tracking-[0.22em] text-neutral-400 dark:text-neutral-500">
                RECORD
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
                <span class="focus-empty text-[clamp(var(--text-xl),0.85rem+0.38vw,var(--text-4xl))] tracking-[0.14em] text-primary-600 opacity-0 transition-opacity duration-200 dark:text-primary-500">
                  --
                </span>
                <audio class="stage-audio" preload="none"></audio>
              </div>

              <%!-- Lead and trail here are set by the hook, not the markup, so
                   the list rests unselected and every row can still reach the
                   band. --%>
              <div
                id={"presence-scroll-#{@selected}"}
                phx-hook="PresencePanel"
                phx-update="ignore"
                class="presence-scroll relative z-10 h-full overflow-y-auto overscroll-contain"
              >
                <ul class="pt-[calc(34vh+4rem)] pb-[30vh]">
                  <li
                    :for={presence <- @current.presences}
                    data-kind={presence.kind}
                    data-media={presence.media}
                    class="presence-item flex h-(--panel-row-h) cursor-pointer items-start px-(--list-pad) whitespace-nowrap pt-[1.15rem] text-[clamp(var(--text-xl),0.85rem+0.38vw,var(--text-4xl))] tracking-[0.14em] text-neutral-900 dark:text-neutral-100"
                  >
                    <%!-- The kind mark leads — two eyes for a face, one mouth for
                         a voice — pinned to the TOP beside the name rather than
                         centred against the two-line block, so it reads on the
                         name's line and the age hangs below it. --%>
                    <.presence_glyph
                      kind={presence.kind}
                      class="mr-3 -mt-[0.28em] text-neutral-400 dark:text-neutral-500"
                    />
                    <div class="flex flex-col leading-tight">
                      <span>{presence.by}</span>
                      <span class="presence-when mt-1 text-neutral-400/55 dark:text-neutral-500/60">
                        {presence.when}
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
              <p class="mb-5 flex items-center gap-3 text-sm tracking-[0.22em] text-neutral-400 dark:text-neutral-500">
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
