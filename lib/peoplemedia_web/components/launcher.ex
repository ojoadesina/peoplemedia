defmodule PeoplemediaWeb.Launcher do
  @moduledoc """
  THE FAB PANEL — what the act opens.

  It is named for the button rather than for its contents, because its contents
  are a registry and will keep growing. What it is NOT is `#panel`, which opens
  under the header when a relationship is picked up: that one is about a person,
  this one is about the app. Two panels doing two jobs, and the names have to
  say which.

  ## ONE OVERLAY, MANY BODIES

  Every room carries `data-room="x"`; anything carrying
  `data-open-room="x"` opens it. Adding a room later is one cell in the
  launcher and one body — no new JavaScript. `launcher.ts` holds the whole
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
  attr :scope_stage, :atom, default: nil
  attr :scope_labels, :map, default: %{mine: nil, theirs: nil}
  attr :scope_error, :any, default: nil
  attr :pending, :map, default: %{incoming: [], outgoing: [], settled: []}
  # THE TWO CLOSED VOCABULARIES, handed in rather than read from the context here
  # — a component that reached into a domain module would be a second place the
  # surface knows where moods come from.
  attr :mood_families, :list, default: []
  attr :activities, :list, default: []
  # WHICH BOX IS OPEN, and what has been chosen so far. Both are the SERVER'S:
  # a mood is data the send will use, not a fact about a gesture, and the room is
  # re-rendered from these rather than reading anything back out of the DOM.
  attr :picker, :any, default: nil
  attr :around_pick, :map, default: %{mood: nil, activity: nil, about: nil}

  def launcher(assigns) do
    ~H"""
    <div
      id="launcher"
      phx-hook="Launcher"
      class="launcher pointer-events-none fixed inset-0 z-40"
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
      <div class="launcher-ground absolute inset-0 bg-light-50 dark:bg-dark-950"></div>

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
      <%!-- NO BOTTOM RESERVATION HERE ANY MORE. This used to hold --launcher-foot
           clear at the bottom of the whole column, for the act — which steps
           aside the moment a room opens, so it was space kept for a button that
           was not there, and it is why the foot sat so far up the screen. The
           clearance belongs to the scrolling BODY, where the content that could
           slide under the foot actually lives; app.css puts it there. --%>
      <div class="launcher-rooms rail relative flex h-full flex-col pt-(--head-top)">
        <%!-- THE MARK COMES WITH YOU. The panel covers the page — masthead and
             all — and a room with nothing of the app at the top of it is a
             screen you could have arrived at from anywhere. It sits on the same
             --list-pad every word does, and the hook replays its entrance each
             time a room opens, so the eyes are drawn on rather than simply
             being there. That replay is the reference's one gesture kept whole:
             the head answering the door. --%>
        <%!-- Centred, like the page's own mark and like everything else in a
             room. It replays its entrance each time one opens — scaling forward
             now rather than sliding in from the edge, since there is no edge
             left to slide from. --%>
        <div class="launcher-head flex justify-center pb-10">
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
          data-room="launcher"
          class="launcher-body min-h-0 flex-1 overflow-y-auto"
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
          <div class="mt-8 flex flex-wrap justify-center gap-x-10 gap-y-12">
            <.cell name="passport" label="PASSPORT">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15 9h3.75M15 12h3.75M15 15h3.75M4.5 19.5h15a2.25 2.25 0 0 0 2.25-2.25V6.75A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25v10.5a2.25 2.25 0 0 0 2.25 2.25Zm6-10.125a1.875 1.875 0 1 1-3.75 0 1.875 1.875 0 0 1 3.75 0Zm1.294 6.336a6.721 6.721 0 0 1-3.17.789 6.721 6.721 0 0 1-3.168-.789 3.376 3.376 0 0 1 6.338 0Z"
              />
            </.cell>

            <.cell name="scoping" label="SCOPING" badge={@unread}>
              <%!-- two interlocked rings — a mutual tie --%>
              <circle cx="8.5" cy="12" r="6" />
              <circle cx="15.5" cy="12" r="6" />
            </.cell>
          </div>

          <.foot master={:close} />
        </div>

        <%!-- ── THE PASSPORT ───────────────────────────────────────────────
             TWO DOORS, FULL WIDTH, and nothing else on the screen. There is
             exactly one question here — have you been before? — and a door for
             each answer is the whole of it.

             REQUEST LEADS because this app is for people who do not have a
             passport yet; check-in is the quieter of the two and wears the
             neutral wash to say so. Square-cornered, like everything else. --%>
        <div
          data-room="passport"
          class="launcher-body min-h-0 flex-1 overflow-y-auto"
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
            <%!-- WHO IS SIGNED IN, HANDED DOWN. It is the one thing this room
                 cannot work out for itself: a nested LiveView mounts with its
                 own session, and without being told it opened on the two doors
                 for everybody — offering a passport to somebody holding one. --%>
            {live_render(@socket, PeoplemediaWeb.PassportLive.Panel,
              id: "passport-panel",
              session: %{"person_id" => @current_person && @current_person.id}
            )}
          </div>
        </div>

        <%!-- ── SCOPING ────────────────────────────────────────────────────
             THE REFERENCE'S SHAPE: sections that only exist when they have
             something in them, each row the other person's name over a line
             saying what is owed and by whom. Server-rendered from the durable
             `scoping` rows, so a reload cannot lose a handshake mid-flight. --%>
        <div data-room="scoping" class="launcher-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>SCOPING</.room_title>

          <p
            :if={
              @pending.incoming == [] and @pending.outgoing == [] and
                Map.get(@pending, :settled, []) == []
            }
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

          <%!-- ── WHAT LANDED ────────────────────────────────────────────────
               THE EVIDENCE. A settled scope leaves the incoming and outgoing
               lists by definition — it is no longer in motion — so a room that
               only showed motion went back to NOTHING IN MOTION the instant you
               finished one, which reads as the thing you just did having failed.
               These rows are not pressable: there is nothing left to decide. --%>
          <.section
            :if={Map.get(@pending, :settled, []) != []}
            title="SCOPED"
            count={length(Map.get(@pending, :settled, []))}
          >
            <div
              :for={{scope, person} <- Map.get(@pending, :settled, [])}
              class="flex w-full items-center gap-6 px-(--list-pad) py-5"
            >
              <span class="min-w-0 flex-1">
                <span class="block truncate text-(length:--sub-type) font-semibold tracking-(--sub-track) text-neutral-600 dark:text-neutral-300">
                  {String.upcase(scope.name)}
                </span>
                <span class="block truncate pt-1 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
                  {String.upcase(person.name)}
                </span>
              </span>
              <%!-- Solid, not an outline: already agreed, nothing to press. --%>
              <span class="flex size-5 shrink-0 items-center justify-center bg-primary-500 text-primary-50 dark:bg-primary-600">
                <svg
                  viewBox="0 0 24 24"
                  class="size-3"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  stroke-linecap="butt"
                  aria-hidden="true"
                >
                  <path d="M5 13l4 4L19 7" />
                </svg>
              </span>
            </div>
          </.section>

          <.foot />
        </div>

        <%!-- ── ONE SCOPE ──────────────────────────────────────────────────
             Where the swipe lands. One question, because the answer IS the act:
             a scope with no name is not a weaker scope, it is a follow, and this
             app does not have those. --%>
        <div data-room="scope" class="launcher-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>{(@scope_target && String.upcase(@scope_target.name)) || "SCOPE"}</.room_title>

          <p
            :if={@scope_error}
            class={[heading_cls(), "px-(--list-pad) pt-6 text-primary-600 dark:text-primary-500"]}
          >
            {String.upcase(@scope_error)}
          </p>

          <%!-- ── ASK — nothing between you yet ───────────────────────────
               A VISITOR CANNOT SCOPE, and the room says so before the press
               rather than after it. The server refuses either way — that check
               is the one that matters and it is not moving — but a live field
               over an armed button is an invitation, and being told to check in
               only once you have thought of a name and typed it is the app
               wasting your time to say something it knew when the room opened. --%>
          <form :if={@scope_stage == :ask} id="scope-form" phx-submit="scope_send" class="pt-6">
            <p class={[heading_cls(), "px-(--list-pad)"]}>
              {(@current_person && "WHAT DO YOU CALL THEM?") || "CHECK IN TO SCOPE ANYONE"}
            </p>
            <.scope_field who={@scope_target} disabled={is_nil(@current_person)} />
            <p class={[heading_cls(), "px-(--list-pad) pt-3"]}>
              THEIRS TO ANSWER, AND THEIRS TO NAME YOU BACK
            </p>

            <div :if={is_nil(@current_person)} class="mt-8 w-(--list-w) max-w-full">
              <.door name="passport" type="button" tone={:quiet}>GET A PASSPORT</.door>
            </div>
          </form>

          <%!-- ── RESPOND — round two, and it is not merely a yes ──────────
               It is where you say what you call THEM, and that claim is theirs
               to see before it stands. This used to be an input and two buttons
               crammed into a list row in the scoping room, which is how they
               ended up overlapping: answering is a screen, not a field in a
               line. --%>
          <form
            :if={@scope_stage == :respond}
            id="scope-form"
            phx-submit="scope_back"
            class="pt-6"
          >
            <input type="hidden" name="other_id" value={@scope_target && @scope_target.id} />
            <p class={[heading_cls(), "px-(--list-pad)"]}>
              {(@scope_labels.theirs &&
                  "THEY CALL YOU “#{@scope_labels.theirs}” — AND YOU CALL THEM?") ||
                "WHAT DO YOU CALL THEM?"}
            </p>
            <.scope_field who={@scope_target} />
            <p class={[heading_cls(), "px-(--list-pad) pt-3"]}>
              THEIRS TO SEAL ONCE YOU HAVE NAMED THEM
            </p>
          </form>

          <%!-- ── REVIEW — both names on the table, and one press seals it --%>
          <div :if={@scope_stage == :review} class="pt-6">
            <p class={[heading_cls(), "px-(--list-pad)"]}>YOU CALL THEM</p>
            <p class={word_cls()}>{@scope_labels.mine}</p>
            <p class={[heading_cls(), "px-(--list-pad) pt-8"]}>THEY CALL YOU</p>
            <p class={word_cls()}>{@scope_labels.theirs}</p>
          </div>

          <%!-- ── STATUS — you asked, and it is not your move ──────────────
               Nothing to fill in, because there is nothing to decide. Offering
               a naming field here is what let the same person be scoped twice:
               it invites an act that has already happened. --%>
          <div :if={@scope_stage == :status} class="pt-6">
            <p class={[heading_cls(), "px-(--list-pad)"]}>
              {(@scope_labels.mine && "YOU CALL THEM “#{@scope_labels.mine}”") || "ALREADY ASKED"}
            </p>
            <p class={[heading_cls(), "px-(--list-pad) pt-3"]}>
              WAITING ON THEM — NOTHING FOR YOU TO DO
            </p>
          </div>

          <p :if={is_nil(@scope_stage)} class={[heading_cls(), "px-(--list-pad) pt-10"]}>
            SWIPE A NAME IN THE LIST TO SCOPE THEM
          </p>

          <%!-- YES AND NO IN ONE ROW, with the way out beneath them. Declining
               used to be a full-width band halfway up the room while accepting
               sat pinned at the foot — two answers to one question, a screen
               apart, drawn as different kinds of object. --%>
          <.foot
            form={(@scope_stage in [:ask, :respond] && "scope-form") || nil}
            icon={scope_icon(@scope_stage)}
            label="Scope them"
            disabled={is_nil(@current_person)}
            master={:hub}
            decline={(@scope_stage in [:respond, :review, :status] && "scope_reject") || nil}
            decline_id={@scope_target && @scope_target.id}
            phx_click={(@scope_stage == :review && "scope_accept") || nil}
            phx_value_id={@scope_target && @scope_target.id}
          />
        </div>

        <%!-- ── AROUND ─────────────────────────────────────────────────────
             THE ROOM THE ACT OPENS, and it is the surface it came from, turned
             into a form.

             IT WAS CALLED A LETTERHEAD AND THAT WAS THE WRONG NAME for what it
             asks. A letterhead is one of three answers here; the thing you are
             filling in is an AROUND — are you here, how are you, what are you
             doing — and calling the room after its last field made the first two
             read as decoration on a letter rather than as the point.

             ITS SHAPE IS THE LIST'S SHAPE. A band on the left and three boxes on
             the right, the same objects at the same sizes: the bar is where the
             words go, and the boxes are the same three that answer the band on
             the page behind. So the form and what it produces are visibly the
             same thing, and nothing has to be learned twice.

             A BOX OPENS ONTO ITS OWN OPTIONS. Pressing one hides its neighbours
             and fills the rail with everything you could choose — moods laid out
             in their families and coloured by them, doings in a plain grid. That
             is the same gesture the boxes make on the page, where opening one
             pushes the others aside; here what it uncovers is a choice rather
             than a longer reading. --%>
        <div data-room="write" class="launcher-body min-h-0 flex-1 overflow-y-auto" hidden>
          <.room_title>
            {(@scope_target && String.upcase(@scope_target.name)) || "AROUND"}
          </.room_title>

          <p
            :if={@scope_error}
            class={[heading_cls(), "px-(--list-pad) pt-6 text-primary-600 dark:text-primary-500"]}
          >
            {String.upcase(@scope_error)}
          </p>

          <form :if={@scope_stage == :write} id="write-form" phx-submit="write_letter" class="pt-8">
            <%!-- THE CHOICES RIDE AS HIDDEN FIELDS. They are made by pressing a
                 word rather than by ticking a control, so the server already
                 holds them by the time this submits — these are the form
                 agreeing with what has already been said, not asking again. --%>
            <%!-- `|| ""` RATHER THAN nil, and it is not cosmetic. HEEx drops an
                 attribute whose value is nil, so an unanswered mood rendered as
                 an input with no `value` at all — and the stylesheet's test for
                 "nothing has been chosen yet" is `[value=""]`, which an absent
                 attribute does not match. The check sat enabled over an empty
                 room, offering an act that would then be refused. --%>
            <input type="hidden" name="mood" value={@around_pick.mood || ""} />
            <input type="hidden" name="activity" value={@around_pick.activity || ""} />

            <p class={[heading_cls(), "px-(--list-pad) pb-5"]}>
              {(@scope_target && "A LETTER TO #{String.upcase(@scope_target.name)}") ||
                "TO THE WORLD"}
            </p>

            <div class="flex flex-col items-stretch gap-6 lg:flex-row lg:items-start">
              <%!-- THE BAR, and it is the page's band with a caret in it. Same
                   wash, same height at rest, same left edge — so a letter looks
                   like the thing it will become before it is written. It grows
                   with what you type and stops at the room's own height; see
                   --compose-max. --%>
              <div class={[
                "around-bar relative flex min-h-(--band-h) w-full shrink-0 items-center",
                "bg-primary-600/15 px-(--list-pad) py-4 lg:w-(--list-w)",
                @picker && "hidden lg:flex",
                "dark:bg-primary-500/20"
              ]}>
                <textarea
                  name="body"
                  rows="1"
                  placeholder="SAY SOMETHING"
                  class="compose-field max-h-(--compose-max) w-full resize-none overflow-y-auto bg-transparent text-(length:--row-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
                ></textarea>
              </div>

              <%!-- THE THREE BOXES, closed. Each says what it holds and opens
                   onto everything it could hold. --%>
              <%!-- WRAPPING, because on a phone the room is one column and three
                   boxes across it are wider than the rail. They centre rather
                   than starting left: this row is the only thing on its line and
                   the room centres everything else. --%>
              <div :if={is_nil(@picker)} class="flex flex-wrap justify-center gap-3 lg:flex-nowrap">
                <button
                  type="button"
                  phx-click="pick_open"
                  phx-value-which="activity"
                  class={[
                    "around-box flex h-(--band-h) w-(--doing-w) shrink-0 cursor-pointer flex-col",
                    "items-start justify-center gap-1 overflow-hidden px-4 text-left outline-none",
                    "bg-neutral-400/10 transition-colors hover:bg-neutral-400/20",
                    "dark:bg-neutral-300/15 dark:hover:bg-neutral-300/25"
                  ]}
                >
                  <span class={heading_cls()}>DOING</span>
                  <%!-- THE SMALLER VOICE, not the row's. On the page these
                       boxes show a fact and the big type is what makes it
                       readable in passing; here they show a CHOICE, and
                       `heartbroken` has to fit whole — a truncated feeling is a
                       different feeling. --%>
                  <span class="w-full truncate text-(length:--sub-type) tracking-(--sub-track) text-light-900 dark:text-dark-100">
                    {String.upcase(@around_pick.activity || "—")}
                  </span>
                </button>

                <button
                  type="button"
                  phx-click="pick_open"
                  phx-value-which="mood"
                  data-family={family_of(@around_pick.mood)}
                  class={[
                    "around-box mood-box flex h-(--band-h) w-(--doing-w) shrink-0 cursor-pointer",
                    "flex-col items-start justify-center gap-1 overflow-hidden px-4 text-left",
                    "outline-none transition-colors",
                    !family_of(@around_pick.mood) &&
                      "bg-neutral-400/10 hover:bg-neutral-400/20 dark:bg-neutral-300/15 dark:hover:bg-neutral-300/25"
                  ]}
                >
                  <span class={heading_cls()}>MOOD</span>
                  <span class="w-full truncate text-(length:--sub-type) tracking-(--sub-track) text-light-900 dark:text-dark-100">
                    {String.upcase(@around_pick.mood || "—")}
                  </span>
                </button>

                <%!-- THE THIRD BOX HAS NOTHING TO ASK YET, and saying so is more
                     honest than filling it. Words go in the bar now, which left
                     this one with no job — and it is the right shape for the job
                     it will have: a face, a voice, or the fact that there is
                     neither. It breathes, because being here with the camera off
                     is still being here, and that is the commonest around there
                     is. --%>
                <div
                  aria-label="Here, with nothing to show yet"
                  class="around-box presence-box relative flex size-(--band-h) shrink-0 items-center justify-center bg-primary-600/15 dark:bg-primary-500/20"
                >
                  <span class="presence-pulse block size-3 bg-primary-600 dark:bg-primary-500"></span>
                </div>
              </div>
            </div>

            <%!-- ── WHAT A BOX OPENS ONTO ──────────────────────────────────
                 MOODS COME IN THEIR FAMILIES, one row each, coloured by the
                 family rather than by the word. Forty-eight hues would be a
                 language nobody could learn; seven is one you pick up by using
                 it, and inside a family the words differ by intensity — annoyed,
                 irritated, furious — so the colour says the weather and the word
                 says the temperature. Vent's idea, muted to this surface's
                 register. --%>
            <div :if={@picker == "mood"} class="flex flex-col gap-6 px-(--list-pad) pt-2">
              <div :for={{family, words} <- @mood_families} class="flex flex-col gap-3">
                <p class={heading_cls()}>{String.upcase(family)}</p>
                <div class="flex flex-wrap gap-2">
                  <button
                    :for={mood <- words}
                    type="button"
                    phx-click="pick"
                    phx-value-which="mood"
                    phx-value-word={mood}
                    data-family={family}
                    class={[
                      "mood-word cursor-pointer px-3 py-2 text-(length:--sub-type) outline-none",
                      "tracking-(--sub-track) text-light-900 transition-colors",
                      "dark:text-dark-100",
                      @around_pick.mood == mood && "is-picked"
                    ]}
                  >
                    {String.upcase(mood)}
                  </button>
                </div>
              </div>
            </div>

            <%!-- DOINGS ARE A PLAIN GRID. They have no families worth colouring
                 — "reading" is not warmer than "walking" — and the thing that
                 makes one specific is the line underneath, which is yours. --%>
            <div :if={@picker == "activity"} class="flex flex-col gap-5 px-(--list-pad) pt-2">
              <div class="flex flex-wrap gap-2">
                <button
                  :for={doing <- @activities}
                  type="button"
                  phx-click="pick"
                  phx-value-which="activity"
                  phx-value-word={doing}
                  class={[
                    "cursor-pointer px-3 py-2 text-(length:--sub-type) tracking-(--sub-track)",
                    "outline-none transition-colors",
                    (@around_pick.activity == doing &&
                       "bg-primary-600/15 text-primary-700 dark:bg-primary-500/20 dark:text-primary-200") ||
                      "bg-neutral-400/10 text-neutral-500 hover:bg-neutral-400/20 hover:text-neutral-700 dark:bg-neutral-300/10 dark:text-neutral-400 dark:hover:bg-neutral-300/20"
                  ]}
                >
                  {String.upcase(doing)}
                </button>
              </div>
              <input
                type="text"
                name="about"
                value={@around_pick.about}
                maxlength="60"
                placeholder="WHAT EXACTLY?"
                class="w-full bg-transparent text-(length:--row-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
              />
            </div>

            <%!-- The `about` line has to reach the form even while its own box is
                 shut, or choosing a doing and closing the picker would throw the
                 words away. --%>
            <input
              :if={@picker != "activity"}
              type="hidden"
              name="about"
              value={@around_pick.about || ""}
            />
          </form>

          <%!-- THE SWIPE IS NO LONGER THE ONLY WAY IN — the act at the foot
               opens this room too — so an instruction naming one of the two
               would be sending people the long way round. --%>
          <p :if={@scope_stage != :write} class={[heading_cls(), "px-(--list-pad) pt-10"]}>
            PRESS THE ACT TO SAY YOU ARE AROUND
          </p>

          <.foot
            form="write-form"
            icon={(@scope_stage == :write && :check) || :none}
            label="Send it"
            back={@picker != nil}
          />
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
      data-open-room={@name}
      class="group flex cursor-pointer flex-col items-center gap-3 outline-none"
    >
      <span class={[
        "launcher-cell relative flex h-[4.5rem] w-[4.5rem] items-center justify-center transition",
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
          class="launcher-badge absolute top-0 right-0 flex min-w-5 -translate-y-1/3 translate-x-1/3 items-center justify-center bg-primary-600 px-1 text-(length:--text-xs) text-primary-50 dark:bg-primary-500"
        >
          {(@badge > 9 && "9+") || @badge}
        </span>
      </span>
      <%!-- THE LABEL SPEAKS IN THE APP'S OWN SMALL VOICE, which is the one
           change to the reference's cell worth making: it was set in a
           semibold 0.2em xs of its own, a hair heavier and a hair tighter than
           every other small word on this surface, and two nearly-identical
           small types read as a mistake rather than as a distinction. --%>
      <span class={heading_cls()}>{@label}</span>
    </button>
    """
  end

  # The scope room's one field, in three stages that all ask the same shape of
  # question. Said once rather than three times, because three copies of a field
  # is three chances for them to drift.
  # THE PERSON'S OWN NAME LEADS IT, then two examples of the kind of thing a
  # label is. "MUM" alone was an instruction rather than a hint — not everybody
  # has one, and nobody has two — and it left the commonest answer unsaid:
  # keeping somebody's own name is always allowed. The reference's exact shape.
  attr :disabled, :boolean, default: false
  attr :who, :any, default: nil

  defp scope_field(assigns) do
    ~H"""
    <input
      type="text"
      name="label"
      value=""
      maxlength="40"
      placeholder={
        [@who && String.upcase(@who.name), "MUM", "COACH…"]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(", ")
      }
      autocomplete="off"
      disabled={@disabled}
      class="w-full bg-transparent pt-6 text-(length:--field-type) tracking-(--row-track) text-light-900 outline-none disabled:opacity-40 dark:text-dark-100"
    />
    """
  end

  # What the forward button means at each step. `:none` where there is nothing
  # to press — a status screen's only acts are withdraw and leave.
  defp scope_icon(:ask), do: :check
  defp scope_icon(:respond), do: :check
  defp scope_icon(:review), do: :check
  defp scope_icon(_), do: :none

  @doc """
  THE ROOM FOOT — the launcher's master button, and beside it whatever the room
  needs. One row, always in this order: get out, go back, go on.

  IT IS PINNED TO THE BOTTOM OF THE VIEWPORT, not left at the end of the
  content, and that is the reference's arrangement rather than a preference.
  Buttons that ride the scroll can be scrolled away from — the country grid and
  the recap are both long enough to hide their own controls — and a way out you
  have to go looking for is not a way out. Every room's content clears it: see
  the padding on `.launcher-body` in app.css, which exists only for this.

  THE MASTER IS THE PANEL'S OWN BUTTON, not the app's. The act at the page's
  foot used to do this job by turning into a cross and then an arrow, which is
  a nice gesture in the wrong place: it left the way out a screen's height from
  the two buttons the form was using. The act steps aside while a room is open
  and this stands in its place.

  IT MEANS TWO THINGS AND SAYS WHICH. At the launcher it is a cross and closes
  the panel; in a room it is an arrow and steps back to the launcher, because a
  room is a place you are in rather than a menu you dismissed. Only the drawing
  is decided here — which of the two happens is the hook's, since only the hook
  knows where you are.

  `back` is the ROOM's own step back, a different question from the master's:
  one leaves the passport, the other returns to the previous field.

  THEY DESCEND BY WHAT THEY DO. The affirmative is the biggest thing in the
  cluster and everything else steps down from it: forward 64, the way out 52,
  a step back or a decline 44. Sizing them alike — which is what happened when
  the master was given the forward's 64 — says the choices weigh the same, and
  on a screen whose whole purpose is one press that is the wrong sentence.

  AND THEY STACK RATHER THAN LINING UP. Three in a row is three equal choices,
  which is not what they are: two of them move you through the room and the
  third leaves it. The reference keeps the pair together on one line and puts
  the way out on its own beneath them — a shape you can read before you read the
  icons. Laid out flat, the master was just the leftmost of three, and the only
  thing saying it meant something different was its colour.
  """
  attr :form, :string, default: nil
  attr :icon, :atom, values: [:next, :check, :none], default: :none
  attr :label, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :back, :boolean, default: false
  attr :master, :atom, values: [:hub, :close], default: :hub
  # A FORWARD THAT IS NOT A SUBMIT. Sealing a handshake decides nothing that
  # needs typing, so that step has a button and no form; without this it would
  # need a one-field form with no fields in it.
  attr :phx_click, :string, default: nil
  attr :phx_value_id, :any, default: nil
  # SAYING NO BELONGS BESIDE SAYING YES. Declining a scope was a full-width door
  # halfway up the room while the way to accept it sat pinned at the foot — two
  # answers to one question, a screen apart, looking nothing like each other.
  # The reference puts them together and draws the refusal as a small cross.
  attr :decline, :string, default: nil
  attr :decline_id, :any, default: nil

  def foot(assigns) do
    ~H"""
    <div class="launcher-foot fixed inset-x-0 bottom-(--foot-bottom) z-20 flex flex-col items-center gap-3">
      <%!-- THE PAIR, on its own line. It only exists in a room that HAS a step
           to take; the launcher, the scoping room and the passport you already
           hold are places rather than steps, and their foot is the way out
           alone. --%>
      <div
        :if={@back or not is_nil(@decline) or @icon != :none}
        class="flex items-center justify-center gap-4"
      >
        <%!-- SAYING NO, BESIDE SAYING YES. It was a full-width band halfway up
             the room while the way to accept sat pinned at the foot — two
             answers to one question, a screen apart, drawn as different kinds
             of object. Small, because refusing is the cheaper act and should
             not be the easiest thing on the screen to hit by accident. --%>
        <button
          :if={not is_nil(@decline)}
          type="button"
          phx-click={@decline}
          phx-value-id={@decline_id}
          aria-label="Decline"
          class="flex size-11 cursor-pointer items-center justify-center bg-neutral-400/10 text-neutral-500 transition-colors hover:bg-neutral-400/20 hover:text-neutral-600 dark:bg-neutral-300/10 dark:text-neutral-400 dark:hover:bg-neutral-300/20"
        >
          <svg
            viewBox="0 0 24 24"
            class="size-5"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="butt"
            aria-hidden="true"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>

        <button
          :if={@back}
          type="button"
          phx-click="back"
          aria-label="Back a step"
          class="flex size-12 cursor-pointer items-center justify-center bg-neutral-400/10 text-neutral-500 transition-colors hover:bg-neutral-400/20 hover:text-neutral-600 dark:bg-neutral-300/10 dark:text-neutral-400 dark:hover:bg-neutral-300/20"
        >
          <.chevron dir="left" />
        </button>

        <%!-- THE FORWARD, and the only solid thing in the row. It is the
           reference's check button, flattened: one square that means "do it",
           the same object whether the room is asking for a name, a code or a
           letter. What was here before was a full-width band with SCOPE THEM
           written across it — a button as wide as the screen for an act that
           is one press, and nothing at all like the pair it sits beside. --%>
        <button
          :if={@icon != :none}
          type={(@phx_click && "button") || "submit"}
          form={@form}
          phx-click={@phx_click}
          phx-value-id={@phx_value_id}
          disabled={@disabled}
          aria-label={@label || ((@icon == :check && "Finish") || "Continue")}
          class="flex size-16 cursor-pointer items-center justify-center bg-primary-500 text-primary-50 transition-colors hover:bg-primary-600 disabled:cursor-not-allowed disabled:opacity-40 dark:bg-primary-600 dark:hover:bg-primary-500"
        >
          <.chevron :if={@icon == :next} dir="right" />
          <svg
            :if={@icon == :check}
            viewBox="0 0 24 24"
            class="size-6"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="butt"
            stroke-linejoin="miter"
            aria-hidden="true"
          >
            <path d="M5 13l4 4L19 7" />
          </svg>
        </button>
      </div>

      <button
        type="button"
        data-launcher-back
        aria-label={(@master == :close && "Close") || "Back to the launcher"}
        class="flex size-13 cursor-pointer items-center justify-center bg-neutral-150 text-neutral-600 transition-colors hover:bg-neutral-200 hover:text-neutral-800 dark:bg-neutral-800 dark:text-neutral-300 dark:hover:bg-neutral-700 dark:hover:text-neutral-100"
      >
        <svg
          :if={@master == :close}
          viewBox="0 0 24 24"
          class="size-6"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="butt"
          aria-hidden="true"
        >
          <path d="M6 6l12 12M18 6L6 18" />
        </svg>
        <svg
          :if={@master == :hub}
          viewBox="0 0 24 24"
          class="size-6"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="butt"
          stroke-linejoin="miter"
          aria-hidden="true"
        >
          <path d="M20 12H5" /><path d="M11.5 5.5 5 12l6.5 6.5" />
        </svg>
      </button>
    </div>
    """
  end

  attr :dir, :string, required: true

  def chevron(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      class="size-6"
      fill="none"
      stroke="currentColor"
      stroke-width="2.5"
      stroke-linecap="butt"
      stroke-linejoin="miter"
      aria-hidden="true"
    >
      <path d={(@dir == "left" && "M15 19l-7-7 7-7") || "M9 5l7 7-7 7"} />
    </svg>
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
      data-open-room={@name}
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
    <div class="w-full pt-10">
      <p class={[heading_cls(), "px-(--list-pad)"]}>{@title} · {@count}</p>
      <div class="pt-4">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  # ONE ROW PER HANDSHAKE: their name, and under it the line that says whose
  # move it is. The phases are the reference's, and so is the wording — it is
  # careful about which side is waiting, which is the only thing anyone reads
  # this list to find out.
  #
  # A ROW IS A NOTIFICATION LINE, NOT A FORM. It used to carry a text input and
  # two buttons inside it, which is why they overlapped: a field and two words
  # cannot share one line in a centred column, and more to the point answering
  # somebody is not a thing you do in a list. Pressing the row opens the scope
  # room at whatever step this particular handshake is at — the trailing arrow
  # is the promise that it goes somewhere.
  attr :entry, :map, required: true

  defp pending_row(assigns) do
    ~H"""
    <button
      :if={@entry.other}
      type="button"
      phx-click="open_scope"
      phx-value-id={@entry.other.id}
      class="group flex w-full cursor-pointer items-center gap-6 px-(--list-pad) py-5 text-left transition-colors hover:bg-neutral-400/10 dark:hover:bg-neutral-300/10"
    >
      <span class="min-w-0 flex-1">
        <span class="block truncate text-(length:--sub-type) font-semibold tracking-(--sub-track) text-neutral-600 dark:text-neutral-300">
          {String.upcase(@entry.other.name)}
        </span>
        <span class="block truncate pt-1 text-(length:--sub-type) text-neutral-400 dark:text-neutral-500">
          {line_for(@entry)}
        </span>
      </span>
      <span class="shrink-0 text-neutral-300 transition-transform group-hover:translate-x-0.5 dark:text-neutral-600">
        →
      </span>
    </button>
    """
  end

  # A small flat answer — the door's language at a row's scale. Not a door,
  # `answer/1` — the small inline button the pending rows used to carry — is
  # gone with them. Answering happens in the scope room now; a room's decisions
  # are `door/1` at full width and `foot/1` at the bottom, and a third button
  # shape existing only for a list row was what made that row impossible to lay
  # out.

  defp line_for(%{phase: "respond", their_label: l}), do: "CALLS YOU “#{l}” — ANSWER"
  defp line_for(%{phase: "review", their_label: l}), do: "SCOPED YOU BACK “#{l}” — FINALISE"

  defp line_for(%{phase: "waiting_accept", my_label: l}),
    do: "YOU ANSWERED “#{l}” · AWAITING THEIR YES"

  defp line_for(%{phase: "waiting_back", my_label: l}), do: "YOU CALL THEM “#{l}” · WAITING"
  defp line_for(_), do: "IN MOTION"

  # THE COLOUR HANGS OFF THE FAMILY, and the room needs it in two places — the
  # closed box and the picked word. Delegated rather than passed in as a third
  # attr: it is a pure fact about the vocabulary, and threading it through the
  # markup would be handing the same lookup down twice.
  defp family_of(mood), do: Peoplemedia.Around.family_of(mood)

  @doc """
  A WORD YOU CAN PRESS, and the same object whether it is a mood or a doing.

  Quiet until chosen, and chosen is a WASH rather than a colour: terracotta means
  "look here" everywhere else on this surface, and a word you have already
  answered is not asking for anything. `peer-checked` because the radio itself is
  `sr-only` — the browser keeps the one-at-a-time rule and the arrow keys, and
  nothing here has to re-implement either.
  """
  def word_pick_cls do
    [
      "block px-3 py-2 text-(length:--sub-type) tracking-(--sub-track) transition-colors",
      "bg-neutral-400/10 text-neutral-500 hover:bg-neutral-400/20 hover:text-neutral-700",
      "dark:bg-neutral-300/10 dark:text-neutral-400 dark:hover:bg-neutral-300/20",
      "dark:hover:text-neutral-200",
      "peer-checked:bg-primary-600/15 peer-checked:text-primary-700",
      "dark:peer-checked:bg-primary-500/20 dark:peer-checked:text-primary-200",
      "peer-focus-visible:underline"
    ]
  end

  @doc "The panel's heading voice — the same small tracked line the list's captions use."
  def heading_cls,
    do: "text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500"

  @doc """
  A NAME BEING HANDED BACK is not a label and not a field — it is the thing
  itself, so it gets the room's largest voice. The passport's recap and the
  scope room's review are the same moment: here is what you said, look at it
  before it stands.
  """
  def word_cls,
    do: "pt-6 text-(length:--count-type) tracking-(--row-track) text-light-900 dark:text-dark-100"

  slot :inner_block, required: true

  defp room_title(assigns) do
    ~H"""
    <p class="px-(--list-pad) text-(length:--count-type) leading-none font-bold tracking-(--row-track) text-light-900 dark:text-dark-100">
      {render_slot(@inner_block)}
    </p>
    """
  end
end
