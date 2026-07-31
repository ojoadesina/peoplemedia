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

    `--list-pad` is THE LIST'S OWN INSET, one step in from that, and it is the
    LIST'S alone now: the row labels, the band's label, the panel's letters, the
    line an empty list writes where a row would be. Rows and the band sharing it
    is what keeps a row's label exactly on top of the band's as it passes
    through, which is the only reason the second edge exists at all.

    THE APP'S FURNITURE TOOK THAT INSET TOO, AND NO LONGER DOES. The mark, the
    strapline and the act were all written from the list's edge on the argument
    that they are words and words step in together. It reads well in a
    screenshot and wrongly in use: it made the page's own furniture answer to a
    column's measurement, so the mark at the top and the act at the bottom moved
    whenever the list did, and the page had no edge of its own to speak of. They
    sit on the rail now. One page edge, and one column standing inside it.

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

  So the split is page-versus-list: the app's own things on the app's edge, and
  the list's own things one step inside it. One number governs the column, and
  moving it moves the column without disturbing anything around it.

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

  alias Peoplemedia.{Directory, Letters, Notifications, Presence, Relationships, Rounds}
  alias Phoenix.LiveView.JS

  # HOW LONG A NEW ROUND WAITS BEFORE IT JOINS THE LIST. Long enough that it
  # never lands under a finger already moving, short enough that it still reads
  # as live. The skeleton stands in its place for exactly this long.
  @landing_ms 2200

  # AND HOW LONG IT WEARS THE COLOUR AFTERWARDS.
  @fresh_ms 6000

  @impl true
  def mount(_params, _session, socket) do
    # WHOSE LIST IS THIS. `current_person` arrives from the session by way of
    # the router's on_mount, and it is what both lists are read for — a visitor
    # holds nobody and is therefore looking at a world entirely of strangers.
    me = socket.assigns[:current_person]
    scopes = Directory.scopes(me)

    # A HANDSHAKE HAS TWO SIDES AND ONLY ONE OF THEM PRESSES ANYTHING. Answering
    # a scope updated the answerer's screen and left the asker looking at a
    # request that had already been dealt with until they reloaded — two people
    # in a two-person act reading different versions of it. The broadcast says
    # only "something changed"; what changed is re-read from the rows.
    # OPENING THE APP IS THE WHOLE GESTURE. There is no press for the silent
    # around: being here is what having the surface open MEANS, so this is the
    # only place it could honestly go.
    #
    # AND A BEAT TO SAY SO AGAIN. Presence renewed by activity would drop anybody
    # who left the tab open and went to make tea — which is a person who is
    # plainly still here. The same beat re-reads the lists, because arounds die
    # QUIETLY: nothing is broadcast when somebody's runs out, so a screen that
    # only redrew on a notification would keep showing people who left.
    # EVERY OPEN LIST LISTENS TO THE SURFACE, passport or not. A visitor watching
    # the People list is watching the same rows as anybody else, and the thing
    # they were missing — somebody going round — is not addressed to them and so
    # never reached their own topic.
    if connected?(socket), do: Notifications.subscribe_surface()

    if connected?(socket) && me do
      Notifications.subscribe(me.id)
      Presence.touch(me.id)
      :timer.send_interval(Presence.beat_ms(), self(), :beat)
    end

    {:ok,
     socket
     |> assign(
       scopes: scopes,
       unscopes: Directory.unscopes(me),
       countries: Directory.countries(me),
       # YOUR OWN PAGE'S SUBJECT, held whether or not you are on it — it is one
       # press away at all times, and reading it on the way in costs a query
       # that the surface is already making five of.
       me_page: Directory.me(me)
     )
     # WHICH LIST YOU OPEN ON depends on whether you have one. SCOPED is the
     # list's subject and the right default for anyone who holds people — but
     # for a visitor, and for a passport on its first morning, it is empty, and
     # opening on an empty list makes an app look broken when it is merely new.
     |> assign(
       list_mode: :people,
       scope: (scopes == [] && "UNSCOPED") || "SCOPED",
       location: (me && me.country) || "Finland"
     )
     |> assign(selected: nil, mode: :list)
     # THE FAB PANEL asks two things of the server: who is signed in, so the
     # launcher knows whether to offer a passport or a way to get one, and how
     # much is waiting, for the badge. Both are assigns rather than hook state
     # because both are facts the process owns.
     |> assign(unread: unread_for(me))
     |> assign(scope_target: nil, scope_error: nil, scope_stage: nil)
     # WHICH BOX IN THE AROUND ROOM IS OPEN, and what has been chosen. Both are
     # the server's: a mood is data the send will use, not a fact about a
     # gesture in one browser, and holding it here is what lets the room be
     # re-rendered from state rather than read back out of the DOM.
     |> assign(going: false, picker: nil, round_pick: blank_round())
     # ── HOW NEWS ARRIVES ──────────────────────────────────────────────────
     # `live` is whether it arrives at all; `waiting` counts what is being held
     # while it does not. `landing` is true between somebody going round and the
     # list taking them in — the pause the skeleton fills. `fresh` is the one
     # person who has just arrived, and it is ONE on purpose: two rows wearing
     # "this is new" is a page of new rows, which is a feed refreshing.
     |> assign(live: true, waiting: 0, landing: false, fresh: nil, seen: %{})
     |> assign(pending: pending_for(me))
     |> assign(live: Enum.filter(scopes, &(&1.state == "live")))
     |> put_list()
     |> put_current()
     |> put_seen()}
  end

  # ── WHO THE PANEL IS ABOUT ──────────────────────────────────────────────────
  # ONE PANEL, TWO WAYS TO BE IN IT. Picking a name out of the band opens it over
  # that person; pressing the self button opens it over you. They are the same
  # room — a person's name and the letters under it — so the markup reads ONE
  # assign rather than branching on the mode in a dozen places.
  #
  # STORED RATHER THAN COMPUTED IN THE TEMPLATE, for the reason `put_list/1`
  # gives: a function call in `~H` switches change tracking off for the block
  # around it.
  defp put_subject(socket) do
    subject =
      case socket.assigns do
        %{mode: :self, me_page: page} -> page
        %{mode: :open, current: current} -> current
        _list -> nil
      end

    # WHAT THE PANEL'S IDS ARE KEYED ON, carried beside the subject because it
    # answers the same question. The ids exist to re-mount the hooks when the
    # subject changes, and `selected` is an index into a list your own page is
    # not in — so on the self page it is nil or, worse, stale, and the letters
    # would be patched into a scroller still holding the last person's scroll
    # position.
    key = (socket.assigns.mode == :self && "self") || socket.assigns.selected

    assign(socket, subject: subject, panel_key: key)
  end

  # Both lists are read for the same person, so they are reloaded together — a
  # scope that appeared in one and not the other would be somebody in two places.
  defp reload_lists(socket), do: socket |> reread() |> reset_list()

  # RE-READING IS NOT THE SAME AS STARTING OVER. Everything the surface stands on
  # comes back from the rows; where the band is standing does not move.
  #
  # `reload_lists/1` drops the selection as well, which is right after YOU acted
  # — you scoped somebody, the list changed under you, and the old index points
  # at a different person. It is wrong when SOMEBODY ELSE acted: having your
  # place in the list taken away because a stranger answered a handshake is the
  # app fidgeting on their behalf.
  defp reread(socket) do
    me = socket.assigns.current_person

    socket
    |> assign(scopes: Directory.scopes(me), unscopes: Directory.unscopes(me))
    # YOUR OWN PAGE IS RE-READ WITH THE REST. It is where a letterhead you just
    # wrote appears, and a page that only caught up on reload would be the one
    # surface in this app that could not show you your own act.
    |> assign(me_page: Directory.me(me))
    |> assign(unread: unread_for(me), pending: pending_for(me))
  end

  # Nobody signed in has nothing waiting — and asking the database on behalf of
  # a visitor would be a query with no subject.
  # What is still in flight, for the scoping room. Read from the durable
  # `scoping` rows rather than held anywhere, so a reload cannot lose it.
  # WHAT THE SCOPING ROOM HOLDS: the handshakes in flight, and the ones that
  # landed. The settled ones were missing, so finalising a scope made the room
  # go back to saying NOTHING IN MOTION — technically true and a terrible answer
  # to "did that work?". The reference keeps them, and it is right to: a room
  # about scoping with no evidence any scoping ever happened is a waiting area.
  defp pending_for(nil), do: %{incoming: [], outgoing: [], settled: []}

  defp pending_for(person) do
    person.id
    |> Relationships.pending_scopes_for()
    |> Map.put(:settled, Relationships.held_by(person.id))
  end

  defp unread_for(nil), do: 0
  defp unread_for(person), do: Peoplemedia.Notifications.unread_count(person.id)

  # SOMEBODY ELSE MOVED. Re-read everything this surface stands on; the message
  # carries nothing, so there is no version of this that can be out of step with
  # the database.
  # YOUR OWN BUSINESS LANDS AT ONCE. A handshake answered, a letter arrived —
  # holding one of those back would be the app withholding your own post.
  @impl true
  def handle_info(:stir, socket),
    do: {:noreply, socket |> reread() |> put_list() |> put_current() |> put_seen()}

  # ── SOMEBODY ELSE MOVED ─────────────────────────────────────────────────────
  # NOT AT ONCE, AND NOT SILENTLY. A round dropping straight in reorders the list
  # under a finger that was reading it — the row you were about to press is now
  # one lower and you pressed the wrong person. So it waits a beat, says a
  # SKELETON is coming while it does, and arrives wearing the colour of a thing
  # that just happened.
  #
  # ONE TIMER, NOT ONE PER STIR. Five people going round in the same second is
  # one arrival as far as a reader is concerned; scheduling five would make the
  # list twitch five times.
  def handle_info(:surface_stir, %{assigns: %{live: false}} = socket) do
    # HELD, AND COUNTED. Turning the feed off is asking not to be moved; the
    # count is the offer to catch up, which is a different thing from being made
    # to.
    {:noreply, assign(socket, waiting: socket.assigns.waiting + 1)}
  end

  def handle_info(:surface_stir, %{assigns: %{landing: true}} = socket),
    do: {:noreply, socket}

  def handle_info(:surface_stir, socket) do
    Process.send_after(self(), :land, @landing_ms)
    {:noreply, assign(socket, landing: true)}
  end

  def handle_info(:land, socket), do: {:noreply, land(socket)}

  # AND IT FADES BACK ON ITS OWN. A row that stayed marked would be a row that
  # is permanently new, which is the same as no mark at all.
  def handle_info(:dissolve, socket), do: {:noreply, assign(socket, fresh: nil)}

  # STILL HERE, AND WHO ELSE IS. The two halves of the beat: say so, and find
  # out. It re-reads rather than settling, so a list that quietly lost somebody
  # does not also lose the reader's place in it.
  def handle_info(:beat, socket) do
    me = socket.assigns.current_person

    if me do
      Presence.touch(me.id)
      # AND THE ROUND GOES ON WHILE ITS CREATOR DOES. It expires forty-five
      # minutes after THEY go quiet, not after the last person to say something,
      # so the beat that says "still here" is the same one that keeps it up.
      Rounds.keep(me.id)
    end

    {:noreply, socket |> reread() |> put_list() |> put_current() |> put_seen()}
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
      # THE BAND IS BEHIND YOUR OWN PAGE, so this cannot be reached from it — but
      # a mode with no clause would fall through to a band press meaning nothing,
      # and `subject` and `mode` would then be free to disagree about which panel
      # is open. Named, so they cannot.
      {_, _, :self} ->
        {:noreply, socket |> assign(mode: :list) |> put_subject()}

      {_, nil, _} ->
        {:noreply, socket}

      # Over a place the band only SELECTS. Committing belongs to the counts,
      # because pressing one also says WHICH population you want, and a band
      # press could not answer that second question.
      {:location, _, _} ->
        {:noreply, socket}

      {:people, _, :open} ->
        {:noreply, socket |> assign(mode: :list) |> put_subject()}

      {:people, _, :list} ->
        {:noreply, socket |> assign(mode: :open) |> put_subject()}
    end
  end

  # ── YOUR OWN PAGE ───────────────────────────────────────────────────────────
  # NOT A ROW IN THE LIST AND NOT A ROOM IN THE LAUNCHER. What it holds is a
  # person's name and the letters under it, which is exactly what the panel is
  # for; the only unusual thing about it is that the person is you.
  #
  # IT WAS VERY NEARLY A ROW AT THE HEAD OF THE LIST, muted, with the composer
  # hidden behind a swipe. That put a control in the one place on this surface
  # that has to stay a list of other people — and it made the list's own geometry
  # depend on how much you had typed, which the band measures rows against.
  #
  # A VISITOR HAS NO PAGE, because a page is the letters you have written and
  # they cannot have written any.
  def handle_event("open_self", _params, socket) do
    case {socket.assigns.current_person, socket.assigns.mode} do
      {nil, _} -> {:noreply, socket}
      {_me, :self} -> {:noreply, socket |> assign(mode: :list) |> put_subject()}
      {_me, _} -> {:noreply, socket |> assign(mode: :self) |> put_subject()}
    end
  end

  # ── THE ACT WRITES A LETTERHEAD ─────────────────────────────────────────────
  # TWO HALVES OF ONE PRESS, the pattern the row's own buttons already use: the
  # server is told WHO, and the hook opens the room — `data-open-room="write"` on
  # the button. Neither can do this alone; the target lives in the process and
  # the panel's open state lives in the browser.
  #
  # WHO IS READ OFF THE SURFACE, NOT SENT BY THE BROWSER, which is what makes
  # the two impossible to disagree about — and it means nobody is ever asked to
  # answer "who is this for?" in a form.
  #
  # AN OPEN PANEL TARGETS AND NOTHING ELSE DOES. Being IN somebody's page is the
  # claim; a name merely passing under the band is not one, and a button whose
  # meaning changed as the list scrolled would be a button you had to check
  # before pressing. Your own page does not target either — that is the whole
  # point of it.
  # ── GOING ROUND ─────────────────────────────────────────────────────────────
  # NO PANEL. It opened a room over the whole page, which is a great deal of
  # screen for four short answers — and it hid the very thing the round is about
  # to join. The creation UI takes the BAND'S place instead: the band is the top
  # marked area, it is already the shape of what a round produces, and leaving
  # the list underneath means you can see who you are going round among while
  # you do it.
  #
  # THE PLUS AND NOTHING ELSE OPENS IT. Not a press on the band — that is one
  # thumb-width from the row you were reading, and a misfire would drop you into
  # a form you never asked for. A dedicated button costs a deliberate reach,
  # which is the right price for a deliberate act.
  def handle_event("go_round", _params, socket) do
    {:noreply,
     socket
     # A FRESH FORM EVERY TIME. What you were part way through saying an hour ago
     # is not an answer to being asked again now.
     |> assign(going: true, picker: nil, round_pick: blank_round())
     # THE LIST IS RESET, not merely left alone. The form has taken the band's
     # line, so a picked name would be claiming it at the same time — and the
     # list is re-read because anything that arrived while you were reading it
     # should be there before you add to it, not after.
     |> assign(mode: :list, selected: nil)
     |> reread()
     |> put_list()
     |> put_current()}
  end

  # SEND AS IS. Everything on the form is optional, so there is nothing to refuse
  # — an empty round is "I am here and open to being joined", which is the
  # smallest true thing anybody can say here and the one this surface exists for.
  def handle_event("round_send", params, socket) do
    me = socket.assigns.current_person

    # THE FORM CARRIES ALL OF IT, and that is what the hidden fields are for. A
    # mood is chosen by pressing a word rather than by ticking a control, so the
    # server holds it in order to RE-RENDER the boxes — but it also puts it back
    # into the form, and a shut picker keeps its answer in a hidden input rather
    # than dropping out of the DOM. So the post is complete either way, and the
    # submit trusts the form the way every other form here does.
    said =
      params
      |> Map.take(~w(mood doing))
      |> Map.merge(audience_for_tab(socket.assigns.scope))

    case me && Rounds.go(me.id, said) do
      nil ->
        {:noreply, assign(socket, going: false)}

      {:ok, round} ->
        # EVERY OPEN LIST REDRAWS. Going round changes the boxes on your row and
        # the order the names come in, for everybody who can see it — and who
        # that is gets decided on the READ, so the nudge can be sent to all.
        Notifications.stir_all()
        tell_the_audience(me, round)

        {:noreply,
         socket
         |> assign(going: false, picker: nil, round_pick: blank_round())
         |> reread()
         |> put_list()
         |> put_current()
         |> push_event("toast", %{words: round_receipt(socket.assigns.scope, said)})}

      {:error, _} ->
        {:noreply, push_event(socket, "toast", %{words: "THAT DID NOT GO THROUGH"})}
    end
  end

  # MANUAL CANCEL, and it is the only way out that changes nothing. Sending is
  # the other door and it commits; a form with one exit would make every escape
  # an act.
  # ── BEING MOVED, OR NOT ─────────────────────────────────────────────────────
  # TURNING IT OFF IS ASKING NOT TO BE MOVED, so nothing arrives until you say
  # so — and turning it back on takes in whatever was held, because that is what
  # asking for it means.
  def handle_event("toggle_live", _params, socket) do
    socket = assign(socket, live: !socket.assigns.live)
    {:noreply, (socket.assigns.live && land(socket)) || socket}
  end

  # THE COUNT IS AN OFFER, not a notice. Pressing it is the reader choosing the
  # moment the list moves under them, which is the whole point of holding it.
  def handle_event("catch_up", _params, socket), do: {:noreply, land(socket)}

  def handle_event("round_cancel", _params, socket) do
    {:noreply, assign(socket, going: false, picker: nil, round_pick: blank_round())}
  end

  def handle_event("write_head", _params, socket) do
    them =
      case socket.assigns do
        %{mode: :open, current: %{id: id}} -> Peoplemedia.People.get_person(id)
        _otherwise -> nil
      end

    {:noreply,
     socket
     |> assign(scope_target: them, scope_error: nil, scope_stage: :write)
     # A FRESH ROOM EVERY TIME. What you were part way through saying an hour ago
     # is not an answer to being asked again now — and an around left half filled
     # in would send a mood you had forgotten choosing.
     |> assign(picker: nil, round_pick: blank_round())}
  end

  # ── OPENING A BOX ONTO ITS OWN OPTIONS ──────────────────────────────────────
  # THE SAME GESTURE THE BOXES MAKE ON THE PAGE: press one and its neighbours get
  # out of the way. What it uncovers here is a choice rather than a longer
  # reading, which is the only difference between the two.
  #
  # PRESSING THE OPEN ONE CLOSES IT, so the way out is the way in — the room's
  # back arrow does the same thing for anybody who reaches for that instead.
  def handle_event("pick_open", %{"which" => which}, socket) do
    open = if socket.assigns.picker == which, do: nil, else: which
    {:noreply, assign(socket, picker: open)}
  end

  # THE ROOM'S BACK ARROW SHUTS THE OPEN BOX. It only appears while one is open,
  # and without a handler here it appeared and then took the process down —
  # `foot/1` renders `phx-click="back"` unconditionally when asked for a back,
  # and the passport room, which is where that button was written, is a different
  # LiveView with its own handler. A shared component's events are not shared.
  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, picker: nil)}
  end

  # CHOOSING CLOSES IT. There is exactly one mood and one doing, so a grid that
  # stayed open after a press would be waiting for an answer already given.
  #
  # AND CHOOSING THE CHOSEN ONE CLEARS IT. Every other answer in this room can be
  # left blank, so the one that has been given has to be retractable — otherwise
  # a mood picked by accident is a mood you have to send.
  def handle_event("pick", %{"which" => which, "word" => word}, socket) do
    key = String.to_existing_atom(which)
    pick = socket.assigns.round_pick
    next = if pick[key] == word, do: nil, else: word

    {:noreply, assign(socket, round_pick: Map.put(pick, key, next), picker: nil)}
  end

  # ── WHAT IS BEING TYPED IS THE SERVER'S ─────────────────────────────────────
  # AND IT HAS TO BE. Pressing a box re-renders the form — the picker opens
  # inside it — so anything the browser was holding alone is wiped by the patch
  # that answers the press. The name went first: type a title, reach for a mood,
  # and the title was gone by the time the moods arrived.
  #
  # A ROUND TRIP PER KEYSTROKE, and here it is worth it. The argument against it
  # is for a LETTER, which is long and whose only reader is the person it goes
  # to; a round's name is a title capped at eighty characters, and it shares a
  # form with three controls that each re-render the thing it sits in. Holding it
  # in one place is what makes the form survive being used.
  def handle_event("round_change", _params, socket) do
    # NOTHING TO KEEP. The doing is the browser's while it is being written and
    # the mood is set by pressing a word, so a change event has no news in it —
    # the handler stays because the form declares one, and a form that announced
    # changes to a LiveView with no clause for them would crash on the first key.
    {:noreply, socket}
  end

  # ── SCOPING ─────────────────────────────────────────────────────────────────
  # THE SWIPE NAMES SOMEBODY, and this is the half of that press the server
  # owns: who. The other half — opening the room — is the hook's, because the
  # panel's open state lives in the browser.
  def handle_event("pick_person", %{"id" => id, "act" => act}, socket) do
    them = Peoplemedia.People.get_person(id)
    me = socket.assigns.current_person

    # OPENING A THREAD IS READING IT. Asking for a second press to admit you
    # read something is asking you to do the app's bookkeeping.
    if (act == "write" and me) && them, do: Letters.mark_read(me.id, them.id)

    {:noreply,
     socket
     |> assign(scope_target: them, scope_error: nil, scope_stage: stage_for(me, them, act))
     |> then(&((act == "write" && reload_lists(&1)) || &1))}
  end

  # LOOKING AT IT IS READING IT. The badge counted rows that were still unread
  # in the table, and nothing marked them — so after finalising a scope the
  # count sat there claiming something was waiting in a room that was empty. A
  # badge that cannot go down is not a badge, it is a decoration.
  #
  # Only the kinds this room actually answers for. A letter waiting elsewhere is
  # not read by opening the scoping room, and clearing it here would lose it.
  def handle_event("seen_scoping", _params, socket) do
    me = socket.assigns.current_person

    if me do
      Notifications.mark_read(me.id, ~w(scope_request scope_back scope_accepted))
      {:noreply, assign(socket, unread: unread_for(me))}
    else
      {:noreply, socket}
    end
  end

  # Answering a handshake from the scoping room: the same room, opened at the
  # step this particular handshake is actually at.
  def handle_event("open_scope", %{"id" => id}, socket) do
    me = socket.assigns.current_person
    them = Peoplemedia.People.get_person(to_id(id))

    {:noreply,
     socket
     |> assign(scope_target: them, scope_error: nil, scope_stage: stage_for(me, them, "scope"))
     |> push_event("launcher:room", %{room: "scope"})}
  end

  # WHAT YOU CALL THEM IS THE WHOLE ACT. A scope with no name is not a weaker
  # scope, it is a different thing — a follow — and this app does not have those.
  def handle_event("scope_send", %{"label" => label}, socket) do
    me = socket.assigns.current_person
    them = socket.assigns.scope_target
    label = String.trim(label)

    cond do
      is_nil(me) ->
        {:noreply, assign(socket, scope_error: "Check in first.")}

      is_nil(them) ->
        {:noreply, assign(socket, scope_error: "Nobody chosen.")}

      label == "" ->
        {:noreply, assign(socket, scope_error: "What do you call them?")}

      true ->
        # THE ANSWER IS USED, and it was thrown away before. `request_scope`
        # already refuses to write a duplicate and says WHICH of three things
        # happened; matching `{:ok, _}` and carrying on regardless meant asking
        # somebody you already hold pinged them for a write that never occurred.
        case Relationships.request_scope(me.id, them.id, String.upcase(label)) do
          {:ok, :already_scoped} ->
            {:noreply, assign(socket, scope_error: "You already hold them.")}

          {:ok, status} when status in [:sent, :already_pending] ->
            # THEY ARE TOLD, durably. A scope request riding only on a live
            # broadcast would be lost on anyone who was not looking.
            {:ok, _} =
              Notifications.notify(them.id, "scope_request", me.id, %{
                "label" => String.upcase(label)
              })

            {:noreply, socket |> answered() |> push_event("launcher:room", %{room: "scoping"})}

          {:error, _} ->
            {:noreply, assign(socket, scope_error: "That did not go through.")}
        end
    end
  end

  # WRITING IS THE ONE ACT THIS APP IS FOR, and text is the whole of it for now:
  # a voice and a face need a recorder, and this needs none. The write path is
  # the same either way, so proving it with words proves it.
  #
  # ONE HANDLER, TWO KINDS OF LETTER, and the difference is entirely whether
  # there is a target. `scope_target` being nil used to mean "nothing has been
  # picked yet" and now also means "addressed to nobody" — which is safe only
  # because `scope_stage` is what says the room is open for writing at all, so
  # this is never reached by somebody who has simply not chosen.
  def handle_event("write_letter", params, socket) do
    me = socket.assigns.current_person
    them = socket.assigns.scope_target
    body = params |> Map.get("body", "") |> String.trim()

    # HOW YOU ARE AND WHAT YOU ARE DOING COME THROUGH THE SAME PRESS. The room
    # asks three things and the letter is only the last of them, so an answer to
    # any one of them is a complete act — a mood on its own is a thing worth
    # saying, and demanding a letter to go with it would make the quieter half of
    # the feature unreachable.
    standing = Map.take(params, ~w(mood doing about))
    said = Enum.any?(Map.values(standing), &(&1 not in [nil, ""]))

    cond do
      is_nil(me) ->
        {:noreply, assign(socket, scope_error: "Check in first.")}

      body == "" and not said ->
        {:noreply, assign(socket, scope_error: "Say something.")}

      true ->
        case around_then_letter(me, them, standing, said, body) do
          {:ok, _} ->
            # THEY ARE TOLD ONLY IF THERE IS A THEY. A letterhead is not
            # addressed to anybody, so a badge for it would be the app inventing
            # an obligation — and one nothing on their screen could discharge,
            # which is the exact fault `seen_scoping` exists to prevent.
            if them && body != "", do: {:ok, _} = Notifications.notify(them.id, "letter", me.id)

            {:noreply,
             socket
             |> answered()
             |> push_event("launcher:room", %{room: nil})
             |> push_event("toast", %{words: receipt(them, body, standing)})}

          {:error, :no_relationship} ->
            {:noreply, assign(socket, scope_error: "Scope them first.")}

          {:error, _} ->
            {:noreply, assign(socket, scope_error: "That did not go through.")}
        end
    end
  end

  # ── THE HANDSHAKE, ROUNDS TWO AND THREE ─────────────────────────────────────
  # Round one is the swipe. These are the answers, and they are the whole reason
  # the scoping room exists: a request you can see but not answer is a notice,
  # not a handshake.
  # A VISITOR CANNOT ANSWER A HANDSHAKE THEY CANNOT HAVE, and all three of these
  # used to reach for `me.id` without checking — so a visitor who found his way
  # to one of these buttons took the process down rather than being told no.
  def handle_event("scope_back", %{"other_id" => id, "label" => label}, socket) do
    me = socket.assigns.current_person
    label = String.trim(label)

    cond do
      is_nil(me) ->
        {:noreply, assign(socket, scope_error: "Check in first.")}

      label == "" ->
        {:noreply, assign(socket, scope_error: "What do you call them?")}

      true ->
        {:ok, _} = Relationships.scope_back(me.id, to_id(id), String.upcase(label))
        {:ok, _} = Notifications.notify(to_id(id), "scope_back", me.id)
        {:noreply, socket |> answered() |> push_event("launcher:room", %{room: "scoping"})}
    end
  end

  def handle_event("scope_accept", %{"id" => id}, socket) do
    me = socket.assigns.current_person
    other = to_id(id)

    cond do
      is_nil(me) ->
        {:noreply, assign(socket, scope_error: "Check in first.")}

      true ->
        case Relationships.accept(me.id, other) do
          {:ok, _} ->
            {:ok, _} = Notifications.notify(other, "scope_accepted", me.id)
            {:noreply, socket |> answered() |> push_event("launcher:room", %{room: "scoping"})}

          {:error, _} ->
            {:noreply, assign(socket, scope_error: "Not ready yet.")}
        end
    end
  end

  # UNSCOPING IS NOT DELETING EITHER. Both sides drop to strangers — the same
  # place a decline leaves them — so the tie is still tracked, still hidden, and
  # can be asked for again. What you called each other is kept; only the type
  # says stranger. "Have we ever spoken?" keeps an answer.
  #
  # THE SECOND PRESS IS THE BROWSER'S BUSINESS. This handler is only ever
  # reached by one, because the first is stopped before it leaves the page —
  # see the Confirm hook. Putting the arming here would mean a half-armed
  # server that a reload or a second tab could get out of step with.
  def handle_event("unscope", %{"id" => id}, socket) do
    me = socket.assigns.current_person
    other = to_id(id)

    cond do
      is_nil(me) ->
        {:noreply, assign(socket, scope_error: "Check in first.")}

      true ->
        case Relationships.unscope(me.id, other) do
          {:ok, _} ->
            {:ok, _} = Notifications.notify(other, "unscoped", me.id)
            {:noreply, reload_lists(socket)}

          {:error, _} ->
            {:noreply, assign(socket, scope_error: "You do not hold them.")}
        end
    end
  end

  # A DECLINE DELETES NOTHING. Both sides become strangers — tracked, hidden and
  # re-askable — so "have we ever spoken?" keeps an answer.
  def handle_event("scope_reject", %{"id" => id}, socket) do
    me = socket.assigns.current_person

    if is_nil(me) do
      {:noreply, assign(socket, scope_error: "Check in first.")}
    else
      {:ok, _} = Relationships.reject(me.id, to_id(id))
      {:noreply, socket |> answered() |> push_event("launcher:room", %{room: "scoping"})}
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
  # right, and they were two doors into the same room — press one population or
  # the other. But you are only ever in one of them at a time, and a
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

  # A LETTERHEAD GOES TO THE WORLD, and for now that is not a choice anybody is
  # offered. The column holds `relationships` too, so the day the room grows a
  # pair of words to pick between, this line is where the answer arrives — no
  # migration, and nothing else moves.
  # THE ROUND FIRST, THEN THE WORDS, and the order is the sentence: here I am and
  # this is what it is about, and here is the first thing I have to say. It also
  # means a bad mood word fails BEFORE anything is written, so nobody ends up
  # having said something whose state they cannot see.
  #
  # GOING ROUND IS A NEW ROW EVERY TIME. It does not edit the last one and it
  # does not revive an expired one — the old round keeps its words and its place
  # in the history, and this one is simply newer.
  #
  # A ROUND EITHER WAY. How you are is about YOU, not about who the words are
  # addressed to, so writing to one person while restless still puts you round
  # restless. The audience of the ROUND and the address of the WORDS are two
  # different questions and the surface answers both without asking.
  defp around_then_letter(me, them, standing, said, body) do
    with {:ok, _} <- go_round_if(me, them, standing, said) do
      write_if(me, them, body)
    end
  end

  defp go_round_if(_me, _them, _standing, false), do: {:ok, :nothing_said}

  defp go_round_if(me, them, standing, true),
    do: Rounds.go(me.id, Map.merge(standing, audience_for(them)))

  # THE TAB, OR THE PERSON WHOSE PAGE YOU ARE ON. Nobody is ever asked who a
  # round is for: standing on somebody's page aims it at them, and standing on
  # the list means everyone.
  defp audience_for(nil), do: %{"audience" => "public"}
  defp audience_for(them), do: %{"audience" => "private", "target_id" => them.id}

  # A ROOM ANSWERED WITH ONLY A MOOD IS A COMPLETE ACT. There is nothing to write
  # and nothing has gone wrong.
  defp write_if(_me, _them, ""), do: {:ok, :no_letter}

  defp write_if(me, nil, body),
    do: Letters.broadcast(me.id, "world", %{kind: "text", body: body})

  defp write_if(me, them, body), do: Letters.write(me.id, them.id, %{kind: "text", body: body})

  # THE ONE ACT WITH NOWHERE TO REPORT INTO. Everything else this app says is
  # said in the place it is about — an error in the room that caused it, a count
  # on the box it counts — and a send has no such place: the room it was written
  # in closes on the way out, and the thing it is about has already gone.
  #
  # SO IT SAYS WHO IT WENT TO, which is the one fact you can no longer check by
  # looking. The room said it while you were writing; this is the same sentence
  # in the past tense, and the toast is the only screen the two of them share.
  # WHAT ACTUALLY HAPPENED, and it has to be able to say all three. The room asks
  # three questions and any one of them alone is a real answer, so a receipt that
  # only ever reported the letter would leave the two quieter acts landing in
  # silence — which, on a surface where the room closes on the way out, is
  # indistinguishable from nothing having happened at all.
  defp receipt(_them, "", standing), do: "ROUND — #{standing_words(standing)}"
  defp receipt(nil, _body, _standing), do: "SENT TO THE WORLD"
  defp receipt(them, _body, _standing), do: "SENT TO #{String.upcase(them.name)}"

  defp standing_words(standing) do
    ~w(mood doing about)
    |> Enum.map(&standing[&1])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map_join(" · ", &String.upcase/1)
  end

  # AN EMPTY ROUND, and every field on it is optional on purpose: a round with
  # nothing filled in is "I am here and open to being joined", which is the
  # smallest true thing anybody can say here.
  defp blank_round, do: %{mood: nil, doing: nil}

  # ── WHO A ROUND IS FOR IS THE TAB YOU ARE STANDING ON ───────────────────────
  # PEOPLE is everyone, so a round made there is public. RELATIONSHIPS is the
  # people you hold, so a round made there is private to them. Nobody is asked,
  # because the answer is already on screen and a control offering it again would
  # be asking somebody to restate where they are standing.
  # ── WHO IS TOLD ─────────────────────────────────────────────────────────────
  # A PRIVATE ROUND NOTIFIES ITS AUDIENCE and a public one never notifies anyone.
  # That is the guide's own rule, and it follows from Law 3: going round with the
  # people you hold is something you did TOWARD them, and going round publicly is
  # something you did in a room they happen to be in.
  #
  # THE STIR IS SEPARATE AND GOES TO EVERYONE. A redraw is not a notice; this is
  # the notice.
  defp tell_the_audience(_me, %{audience: "public"}), do: :ok

  defp tell_the_audience(me, %{audience: "private", target_id: target}) when not is_nil(target),
    do: Notifications.notify(target, "round", me.id)

  defp tell_the_audience(me, %{audience: "private"}) do
    for {_scope, them} <- Relationships.held_by(me.id),
        do: Notifications.notify(them.id, "round", me.id)

    :ok
  end

  defp audience_for_tab("SCOPED"), do: %{"audience" => "private"}
  defp audience_for_tab(_people), do: %{"audience" => "public"}

  defp round_receipt("SCOPED", said), do: "ROUND WITH YOUR RELATIONSHIPS#{round_words(said)}"
  defp round_receipt(_people, said), do: "ROUND, PUBLICLY#{round_words(said)}"

  defp round_words(said) do
    ~w(doing mood)
    |> Enum.map(&said[&1])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> ""
      words -> " — " <> Enum.map_join(words, " · ", &String.upcase/1)
    end
  end

  # ── TAKING SOMEBODY IN ──────────────────────────────────────────────────────
  # RE-READ, THEN WORK OUT WHO IS NEW BY DIFFING. The broadcast carries nothing —
  # deliberately, so it can be sent to everybody and the READ decides who may see
  # what — which means the surface has to notice the arrival itself. Comparing
  # the round ids it had against the ones it has is the whole of it.
  #
  # THE NEWEST ONE ONLY. Several may have landed while the timer ran; marking all
  # of them would be a page of new rows, which is a feed refreshing rather than
  # somebody arriving.
  defp land(socket) do
    before = socket.assigns.seen

    socket =
      socket
      |> assign(landing: false, waiting: 0)
      |> reread()
      |> put_list()
      |> put_current()

    # SORT AND TAKE THE HEAD, not `Enum.max_by/3` with a fallback — that arity's
    # third argument is a SORTER, and a zero-arity function handed to it is a
    # crash waiting for the first non-empty list.
    fresh =
      socket.assigns.list
      |> Enum.filter(&(&1[:last_round] && &1[:last_round] > Map.get(before, &1[:id], 0)))
      |> Enum.sort_by(& &1.last_round, :desc)
      |> List.first()

    if fresh, do: Process.send_after(self(), :dissolve, @fresh_ms)
    socket |> assign(fresh: fresh && fresh.id) |> put_seen()
  end

  # WHAT THE LIST LOOKED LIKE LAST TIME, so the next arrival has something to be
  # new against. Kept as ids rather than rows: it is a comparison, not a copy.
  defp put_seen(socket) do
    seen = Map.new(socket.assigns.list, &{&1[:id], &1[:last_round] || 0})
    assign(socket, seen: seen)
  end

  defp other_scope("SCOPED"), do: "UNSCOPED"
  defp other_scope(_unscoped), do: "SCOPED"

  # ── WHICH TAG IS LIT ────────────────────────────────────────────────────────
  # ONLY THE PLACE, AND ONLY WHEN THE ROLL OF THE WORLD IS OPEN.
  #
  # The two used to be washed boxes on the right rail and exactly one was lit at
  # a time — whichever the list was obeying. That was right for boxes and is
  # wrong for a caption: as small tracked words at the head of the list, a lit
  # population would read as a WARNING rather than as a state, and terracotta on
  # this surface is rationed to the one thing asking something of you.
  #
  # AND THE POPULATION HAS NO CHOSEN STATE TO SHOW. It is a toggle you can press
  # from either side, and neither side is more selected than the other. The place
  # is different: it can be OPEN, with the whole world scrolling under the band,
  # and that is a state worth a colour.
  #
  # It takes a BOOLEAN rather than assigns, so the caller still names the assign
  # it depends on and change tracking holds.
  defp tag_ink(true), do: "text-primary-600 dark:text-primary-500"

  defp tag_ink(false),
    do:
      "text-neutral-400 hover:text-neutral-500 dark:text-neutral-500 dark:hover:text-neutral-400"

  # AN ID OFF THE WIRE IS A STRING, and an id from anywhere else is not. The
  # browser only ever sends the first kind, so this looks redundant until
  # something calls these directly — and then it is the difference between a
  # handler and a crash.
  defp to_id(id) when is_binary(id), do: String.to_integer(id)
  defp to_id(id) when is_integer(id), do: id

  # WHAT AN EMPTY LIST SAYS, in the two ways it can be empty. Both are ordinary
  # states rather than errors: holding nobody in a place is what every place but
  # one looks like, and a place where you already hold everyone is the good end
  # of the same axis.
  defp empty_line("UNSCOPED"), do: "NOBODY LEFT TO SCOPE"
  defp empty_line(_scoped), do: "NOBODY SCOPED HERE"

  defp empty_hint("UNSCOPED", place),
    do: "EVERYONE IN #{String.upcase(place)} IS ALREADY YOURS"

  defp empty_hint(_scoped, place),
    do: "SWITCH TO PEOPLE, OR TRY A PLACE OTHER THAN #{String.upcase(place)}"

  # Swapping what the list holds makes the old index meaningless — it now points
  # at a different person, or at a country.
  defp reset_list(socket) do
    socket |> assign(selected: nil, mode: :list) |> put_list() |> put_current()
  end

  # ONE SCROLLER, THREE POSSIBLE CONTENTS, chosen by the two tags above it.
  defp current_list(%{list_mode: :location} = assigns), do: assigns.countries
  defp current_list(%{scope: "UNSCOPED"} = assigns), do: in_place(assigns.unscopes, assigns)
  defp current_list(assigns), do: in_place(assigns.scopes, assigns)

  # THE PLACE IS THE LIST'S PARENT, which is the whole reason it sits in a box
  # above it: "Finland → its scopes" rather than "Finland, and separately, some
  # people". Until this filter existed the box counted one thing and the list
  # showed another — Finland claiming six scopes over a list of everybody
  # everywhere — and the two never had to agree because neither read the other.
  #
  # WORLD IS NOT A PLACE, it is the absence of one, so it filters nothing.
  defp in_place(people, %{location: "WORLD"}), do: people
  defp in_place(people, %{location: place}), do: Enum.filter(people, &(&1.country == place))

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

    case socket.assigns do
      # OVER THE ROLL OF PLACES the box follows the band, so it is re-counted on
      # every settle — that is the point of it.
      %{list_mode: :location, current: current} ->
        place = (current && current.name) || "WORLD"

        assign(socket,
          box_place: place,
          box_counts: Directory.population_of(socket.assigns[:current_person], place)
        )

      # IN THE PEOPLE LISTS SCROLLING CANNOT CHANGE IT. The place is whatever
      # was committed; a name passing under the band says nothing about it. This
      # used to count anyway, which meant a database query for every row that
      # went by — a scroll's worth of them for a number already on screen and
      # already right.
      #
      # THE TEST IS AGAINST THE COMMITTED PLACE, not merely "have we counted
      # before". Leaving the roll re-commits `location`, and a box still showing
      # the last place's totals under the new place's name is exactly the
      # disagreement the counts were made real to end.
      %{box_place: place, location: location, box_counts: counts}
      when place == location and is_map(counts) ->
        socket

      %{location: location} ->
        assign(socket,
          box_place: location,
          box_counts: Directory.population_of(socket.assigns[:current_person], location)
        )
    end
    # THE SUBJECT FOLLOWS THE SELECTION, so it is re-derived here rather than at
    # every call site. Anything that changes the MODE without touching the
    # selection has to say so itself — see `toggle_open` and `open_self`.
    |> put_subject()
  end

  # WHERE AN ANSWER LEAVES YOU. Every one of these used to leave the launcher
  # sitting in the room it was already in, with its target cleared — so the
  # completion state of scoping somebody was a room titled SCOPE telling you to
  # swipe a name in a list you could not see. The scoping room is where the
  # thing you just did is now listed, which makes it the honest destination:
  # the new entry there is the receipt.
  # AND WHERE IT DOES NOT LEAVE YOU: somewhere other than where you were. This
  # went through `reload_lists/1`, which drops the selection AND the mode — the
  # right thing when the act changed the list under you, and quietly wrong now
  # that a letter can be written from inside somebody's panel. You wrote to the
  # person whose page you were on, and the page closed.
  #
  # THE PANEL IS PUT BACK AFTERWARDS rather than the reload being made
  # conditional, because the re-read is what makes the letter you just wrote
  # appear in the list under it. Restoring is one line; a second reload path
  # that could drift from the first is not.
  defp answered(socket) do
    %{mode: mode, selected: selected} = socket.assigns

    socket
    |> assign(scope_target: nil, scope_error: nil, scope_stage: nil)
    |> reload_lists()
    |> then(
      &((mode == :list && &1) || &1 |> assign(mode: mode, selected: selected) |> put_current())
    )
  end

  # WHAT THE UNCOVERED ACTION SAYS. The row is where you decide, so it is where
  # the state has to be true — offering SCOPE to somebody you asked yesterday
  # invites an act that will then be refused, which is a worse experience than
  # never offering it. The word matches the step the room will open at.
  defp row_act(%{label: label}) when not is_nil(label), do: "UNSCOPE"
  defp row_act(%{phase: "waiting_back"}), do: "ASKED"
  defp row_act(%{phase: "waiting_accept"}), do: "ANSWERED"
  defp row_act(%{phase: "respond"}), do: "ANSWER"
  defp row_act(%{phase: "review"}), do: "FINALISE"
  defp row_act(_), do: "SCOPE"

  # ── WHICH STEP THE SCOPE ROOM OPENS AT ──────────────────────────────────────
  # THE ROOM ASKS THE QUESTION THAT IS ACTUALLY OUTSTANDING, rather than always
  # asking the first one. Pressing SCOPE on somebody you asked yesterday used to
  # open an empty naming field, which invites you to do a thing that has already
  # been done — and the only thing standing between that and a duplicate was the
  # context layer refusing it afterwards. A duplicate you cannot reach is better
  # than one that is politely declined.
  #
  # Four answers, and each is a different sentence:
  #
  #   :ask      nothing between you — what do you call them?
  #   :respond  they asked you — they call you X, and you call them?
  #   :review   they answered — here are both names; seal it
  #   :status   you asked and they have not answered — nothing to do but wait,
  #             or withdraw
  #
  # A VISITOR ALWAYS GETS :ask, and the room disables itself for them. Their
  # pending list is empty by definition, so there is nothing else it could be.
  defp stage_for(_me, nil, _act), do: nil
  defp stage_for(_me, _them, "write"), do: :write
  defp stage_for(nil, _them, _act), do: :ask

  defp stage_for(me, them, _act) do
    %{incoming: incoming, outgoing: outgoing} = Relationships.pending_scopes_for(me.id)

    cond do
      entry(incoming, them.id) -> :respond
      match?(%{phase: "review"}, entry(outgoing, them.id)) -> :review
      entry(outgoing, them.id) -> :status
      true -> :ask
    end
  end

  defp entry(entries, id), do: Enum.find(entries, &(&1.other && &1.other.id == id))

  # What the room needs to SAY at that step — the other side's word for you, and
  # yours for them. Read at render rather than frozen into the stage, so an
  # answer that lands while the room is open is the one shown.
  defp stage_labels(nil, _them), do: %{mine: nil, theirs: nil}
  defp stage_labels(_me, nil), do: %{mine: nil, theirs: nil}

  defp stage_labels(me, them) do
    %{incoming: incoming, outgoing: outgoing} = Relationships.pending_scopes_for(me.id)

    case entry(incoming, them.id) || entry(outgoing, them.id) do
      nil -> %{mine: nil, theirs: nil}
      e -> %{mine: e.my_label, theirs: e.their_label}
    end
  end

  # ── THE SURFACE ─────────────────────────────────────────────────────────────
  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="scopes"
      class={[
        "app-root fixed inset-0 z-0 bg-light-50 font-mono dark:bg-dark-950",
        @mode in [:open, :self] && "is-open"
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
      <%!-- ── THE MARK, IN THE MIDDLE ──────────────────────────────────────
           IT USED TO SIT ON THE LEFT EDGE with everything else, on the rule that
           a masthead belongs at the start of the line. That rule comes from
           pages, and this is not one — it is a single column of names with a
           band across it, symmetrical about its own centre, and a mark pinned to
           one side of that read as a page's furniture leaning against a column
           it had nothing to do with.

           CENTRED, THE TWO PIECES OF THE APP'S OWN FURNITURE — the mark at the
           top and the act at the bottom — become one axis, and the band and the
           letter box hang off it. It also settles what the launcher's entrance
           should be: the mark no longer has anywhere to travel to, so it stops
           sliding and starts SCALING, which is a better answer anyway. A thing
           that comes forward is arriving; a thing that slides sideways is being
           rearranged. --%>
      <header class="app-head pointer-events-none absolute inset-x-0 top-(--head-top) z-30">
        <div class="rail flex justify-center">
          <button
            id="logo"
            type="button"
            phx-hook="Head"
            class="pointer-events-auto inline-block cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-primary-500/40"
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

           CENTRED, WITH THE MARK. It wore --list-pad so that it would line up
           with the NAMES, which is a real alignment and the wrong one — it made
           the app's furniture answer to the list's edge. Then it moved to the
           rail. It is on the page's CENTRE now, holding one axis with the mark
           at the top: the two things that are the app rather than the list,
           top and bottom of the same line.

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
      <%!-- z-50, above the panel it opens — it is drawn over an opaque ground,
           and at z-30 it was simply painted out. It steps ASIDE while a room is
           open rather than staying to close it: the launcher carries its own
           master button now, standing in the row with the room's own back and
           forward, which is where the way out belongs. --%>
      <%!-- ── THE TOAST ────────────────────────────────────────────────────
           ONE LINE, ABOVE THE ACT, and it exists for exactly one job so far:
           asking whether you meant it. Everything else this app says is said in
           the place it is about — an error in the room that caused it, a count
           on the box it counts. A confirmation has nowhere like that to live,
           because the thing it is about is a press that has not happened yet.

           IT MOVED TO THE TOP RIGHT, and off the act's line. It sat directly
           over the foot, which was right while its only job was asking whether
           you meant a press you had just made — the question and the button
           belonged together. It carries RECEIPTS now as well, and a receipt over
           the controls is a receipt in the way of the next thing you do. The top
           right is the one corner of this surface nothing else claims.

           Client-owned: what it says and whether it is showing are both facts
           about a gesture in one browser. --%>
      <div
        id="toast"
        phx-hook="Confirm"
        phx-mounted={JS.ignore_attributes(["class", "hidden"])}
        class="toast pointer-events-none fixed inset-x-0 top-(--head-top) z-50"
        aria-live="polite"
        hidden
      >
        <div class="rail flex justify-end">
          <%!-- THE WORDS ARE THE CLIENT'S TOO, and leaving that unsaid left the
               toast showing an EMPTY terracotta box.

               The exemption above covers this element's `class` and `hidden`,
               which are what the hook writes on the toast itself — but the line
               inside is an ordinary child, and the server renders it blank
               because a receipt is not something the server can know is on
               screen. So any patch landing inside the six-second window wiped
               the sentence and left the box: opening a panel, settling a row,
               anything at all.

               `phx-update="ignore"` rather than another attribute exemption,
               because what has to survive is the TEXT NODE rather than an
               attribute — and it needs an id to be ignored by. --%>
          <p
            id="toast-line"
            phx-update="ignore"
            class="toast-line inline-block bg-primary-600 px-4 py-3 text-(length:--sub-type) tracking-(--sub-track) text-primary-50 dark:bg-primary-500"
          >
          </p>
        </div>
      </div>

      <%!-- ── THE FOOT: THREE BUTTONS ────────────────────────────────────────
           IT WAS ONE, AND THE ONE MEANT "OPEN THE LAUNCHER" while being drawn
           as a plus. That is two different promises on one button: a plus says
           MAKE SOMETHING, and what it did was open a drawer. The mark was
           honest about the app's intention and dishonest about the press.

           SO THE PLUS KEEPS THE PROMISE AND LOSES THE DRAWER. It writes a
           letterhead, which is the one act this app is for, and the launcher —
           which is everything that would not fit down here — moves to a button
           that looks like what it is. Between them sits YOU: a door to your own
           page, drawn as a container rather than as an action, because it is a
           place rather than a thing to do.

           THE ORDER IS PLACE · ACT · MORE, with the act still dead centre where
           the single button was. A foot that shuffled the primary act sideways
           to make room for two new ones would have moved the only thing anybody
           had learned the position of. --%>
      <div class="app-foot pointer-events-none fixed inset-x-0 bottom-(--foot-bottom) z-50">
        <div class="rail flex items-center justify-center gap-4">
          <%!-- YOUR OWN PAGE. Drawn as a CONTAINER — the band's wash, the
               surface's one "something is held here" ground — rather than as a
               third action in a row of actions, because pressing it takes you
               somewhere instead of doing something.

               AND IT IS EMPTY ON PURPOSE. It carried the head mark and the
               band's brackets, and both were wrong for the same reason: they
               are the surface's AIMING vocabulary. Brackets pick one thing out
               of several and the mark is a placeholder for a face — together
               they made a small box that looked like it was already showing
               something, at a size where that something could only be two
               dashes. An empty wash says "your own" without pretending to hold
               anything, and it is the shape a real face will fill the day a
               passport carries one.

               A VISITOR HAS NO PAGE, so there is no button. A page is the
               letters you have written, and they cannot have written any. --%>
          <button
            :if={@current_person && !@going}
            id="self"
            type="button"
            aria-label="Your own page"
            aria-pressed={to_string(@mode == :self)}
            class={[
              "self-box pointer-events-auto relative flex size-(--act-h) cursor-pointer items-center justify-center",
              "transition-colors outline-none",
              "focus-visible:ring-2 focus-visible:ring-primary-500/40 focus-visible:ring-offset-2",
              "focus-visible:ring-offset-light-50 dark:focus-visible:ring-offset-dark-950"
            ]}
            phx-click="open_self"
          >
          </button>

          <%!-- ── THE FOOT IS THE FORM'S CONTROLS WHILE THERE IS A FORM ─────
               Cancel, send, and the launcher — three positions doing the three
               jobs the moment asks for. It buys the boxes the whole rail back on
               a phone, and it keeps every control this surface has in the one
               place a thumb already knows to reach.

               THE CROSS TAKES YOUR OWN PAGE'S PLACE, on the left, where nothing
               destructive ever was — and the act keeps the centre it has always
               had. A form whose way out and way on were the same button was
               briefly the shape here, and it made the one press you make most
               the one you had to look at first. --%>
          <button
            :if={@going}
            type="button"
            aria-label="Leave without going round"
            phx-click="round_cancel"
            class={[
              "pointer-events-auto relative flex size-(--act-h) cursor-pointer items-center justify-center",
              "bg-neutral-100 text-neutral-600 transition-colors outline-none",
              "hover:bg-neutral-200 hover:text-neutral-800",
              "focus-visible:ring-2 focus-visible:ring-primary-500/40 focus-visible:ring-offset-2",
              "focus-visible:ring-offset-light-50 dark:focus-visible:ring-offset-dark-950",
              "dark:bg-neutral-800 dark:text-neutral-300 dark:hover:bg-neutral-700"
            ]}
          >
            <svg
              viewBox="0 0 24 24"
              class="absolute h-1/2 w-1/2"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="butt"
              aria-hidden="true"
            >
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>

          <%!-- THE ACT, and open it finishes what it started. `form=` because a
               control belongs to a form by id wherever it stands — the form
               itself is the bar up at the band, and this is its submit. --%>
          <button
            id="act"
            type={(@going && "submit") || "button"}
            form={(@going && "round-form") || nil}
            aria-label={(@going && "Go round") || "Start a round"}
            phx-click={(!@going && "go_round") || nil}
            class={[
              "pointer-events-auto relative flex size-(--act-h) cursor-pointer items-center justify-center",
              "bg-primary-500 text-primary-50 transition-colors outline-none hover:bg-primary-600",
              "focus-visible:ring-2 focus-visible:ring-primary-500/40 focus-visible:ring-offset-2",
              "focus-visible:ring-offset-light-50 dark:focus-visible:ring-offset-dark-950",
              "dark:bg-primary-600 dark:hover:bg-primary-500"
            ]}
          >
            <%!-- ONE MARK, ONE MEANING: start something. It used to turn 45
                 degrees into a cross and then crossfade to an arrow, three
                 jobs on one button — which read well and put the way out of a
                 form a screen away from the form. --%>
            <%!-- ONE MARK, ONE MEANING: start something. It briefly turned into
                 a cross, which was right while it was the form's only control —
                 the way out has a button of its own beside it now, so the act
                 goes back to meaning the one thing it has always meant. Open, it
                 finishes what it started. --%>
            <svg
              :if={!@going}
              viewBox="0 0 24 24"
              class="act-mark absolute h-1/2 w-1/2"
              fill="currentColor"
              aria-hidden="true"
            >
              <rect x="4" y="10.25" width="16" height="3.5" />
              <rect x="10.25" y="4" width="3.5" height="16" />
            </svg>
            <svg
              :if={@going}
              viewBox="0 0 24 24"
              class="absolute h-1/2 w-1/2"
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

          <%!-- EVERYTHING THAT WOULD NOT FIT DOWN HERE. Three squares, cut from
               the same 3.5-wide bar the plus is drawn out of, so the two marks
               are visibly the same hand.

               QUIET, AND DELIBERATELY NOT THE ACT'S EQUAL. It wears the wash the
               launcher's own cells wear — this is that panel's door, and a door
               drawn in the colour reserved for ATTENTION would put two primary
               acts side by side and leave neither of them primary. --%>
          <button
            id="more"
            type="button"
            aria-label="Open the launcher"
            aria-expanded="false"
            class={[
              "pointer-events-auto relative flex size-(--act-h) cursor-pointer items-center justify-center",
              "bg-neutral-100 text-neutral-600 transition-colors outline-none",
              "hover:bg-neutral-200 hover:text-neutral-800",
              "focus-visible:ring-2 focus-visible:ring-primary-500/40 focus-visible:ring-offset-2",
              "focus-visible:ring-offset-light-50 dark:focus-visible:ring-offset-dark-950",
              "dark:bg-neutral-800 dark:text-neutral-300 dark:hover:bg-neutral-700 dark:hover:text-neutral-100"
            ]}
          >
            <svg
              viewBox="0 0 24 24"
              class="absolute h-1/2 w-1/2"
              fill="currentColor"
              aria-hidden="true"
            >
              <rect x="4" y="10.25" width="3.5" height="3.5" />
              <rect x="10.25" y="10.25" width="3.5" height="3.5" />
              <rect x="16.5" y="10.25" width="3.5" height="3.5" />
            </svg>
            <%!-- THE COUNT RIDES THE DOOR, not just the room behind it. It sat
                 only on the launcher's scoping cell, which is one press inside
                 a panel nobody opens without a reason to — so the reason to
                 open it was the one thing it could not tell you.

                 AND IT MOVED WITH THE DOOR. It was on the plus while the plus
                 was the way in; now that the plus writes and this button opens
                 the launcher, a badge left behind would be a count sitting on a
                 button that cannot discharge it. --%>
            <span
              :if={@unread > 0}
              class="launcher-badge absolute top-0 right-0 flex min-w-5 -translate-y-1/3 translate-x-1/3 items-center justify-center bg-primary-600 px-1 text-(length:--text-xs) text-primary-50 dark:bg-primary-500"
            >
              {(@unread > 9 && "9+") || @unread}
            </span>
          </button>
        </div>
      </div>

      <.launcher
        socket={@socket}
        current_person={@current_person}
        unread={@unread}
        scope_stage={@scope_stage}
        scope_labels={stage_labels(@current_person, @scope_target)}
        scope_target={@scope_target}
        scope_error={@scope_error}
        pending={@pending}
      />

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
        <%!-- CAPPED, and the cap is the point. At --row-type with 0.15em of
             tracking this runs past the rail on a narrow phone and wraps in the
             middle of a word, so the line that is meant to be read once and
             forgotten becomes the most awkward thing on the page. The clamp
             shrinks the TYPE rather than the tracking, because the tracking is
             what makes it read as a standing sentence rather than as a row. --%>
        <p class="lede text-(length:--lede-type) tracking-[0.15em] whitespace-nowrap text-neutral-250 dark:text-neutral-750">
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
        <div class={[
          "stage-box relative mt-6 min-h-0 w-full flex-1",
          @mode in [:open, :self] && "list-away"
        ]}>
          <%!-- NO phx-update="ignore", and its going was the right call — the
               whole list was frozen to protect two attributes. But "the server
               may patch this" and "the server owns every attribute on it" are
               different claims, and taking the first without saying the second
               is what made the list jump under a moving finger.

               TWO ATTRIBUTES ARE THE CLIENT'S, and they are named below rather
               than defended by exempting the element that carries them. The
               scroller's CLASS holds `is-scrolling` and `has-selection`, which
               are facts about a gesture; the list's STYLE holds the measured
               lead and trail. Neither has a server-side value to lose — the
               class here is a constant and the ul is rendered bare.

               WHY IT MATTERED SO MUCH: a patch reconciles the DOM against the
               server's copy, so an attribute the server never rendered is one
               the server deletes. Losing the padding took ~740px off the
               scroller's height, and the browser CLAMPS a scroll position that
               no longer exists — irreversibly, so putting the padding back a
               frame later does not put the reader back. Then the clamp fires a
               scroll event, and the scroll event starts the cycle again.

               THE ID STILL CARRIES THE MODE, because three lists sharing one
               scroller and one band still need the hook re-run when the rows
               underneath are a different KIND of thing. Anything keyed on this
               element in CSS must use the CLASS, never the id. --%>
          <%!-- ── WHAT THE LIST IS ───────────────────────────────────────────
               WHERE, AND WHICH OF THEM. These two were the first two of the three
               boxes on the right rail, and they were in the wrong place for a
               reason the cluster's own comment gave away: it claimed all three
               "answer the band", and only the third one ever did. A place and a
               population are facts about the LIST — they are the same whichever
               name has scrolled into the band — so they belong at the head of the
               list, and the rail is left to the things that really do answer it.

               AND THEY SIT JUST ABOVE THE BAND, not under the strapline. A
               caption belongs to the thing it captions: up by the lede it was a
               third line of masthead and the list it describes was a screen
               away. Against the band it reads the way LETTERS reads over the
               panel's own column — same offset, same voice, same job.

               THEY LOSE THEIR SIZE AND KEEP THEIR COUNT. As boxes they were a
               wash and a number at --count-type, which is the loudest type on the
               surface; as a caption they are the same small tracked voice the age
               under a name uses. The number stays because it is the answer — how
               many people are actually down there — and a caption that said
               RELATIONSHIPS without saying how many would be a label rather than
               a fact.

               ONLY THE PLACE LIGHTS. The population is a toggle you can press in
               either state, and neither of its states is more chosen than the
               other; lighting it would claim one of them is. The place is
               different — it can be OPEN, with the whole roll of the world
               scrolling under the band — and that is a state worth showing. --%>
          <%!-- `pl-`, NOT `px-`, AND POINTER-EVENTS OFF THE BOX. This is an
               absolutely positioned strip at z-20 sitting directly over the
               rows, so every part of it that is not a tag — the gap between the
               two, and the padding after the last — was an invisible surface
               swallowing presses meant for the list underneath it.

               AND NO PADDING EITHER SIDE. It had --list-pad on the left, which
               is the LIST's inset — where a row's words start, one step in from
               the rail. These are not a row: they are a caption for the whole
               column, so they belong on the RAIL, level with the strapline above
               them and with the band's own left edge below. Indented, they read
               as a row that had lost its name.

               Trailing padding on a shrink-to-fit box shows nothing and costs a
               press, which is the worst trade available.

               The container/child split is the one `.scope-boxes` and
               `.app-foot` already use, and for exactly this reason. --%>
          <div class="list-tags pointer-events-none absolute top-(--tags-top) left-0 z-20 flex items-baseline gap-5">
            <button
              type="button"
              phx-click="place_box"
              aria-pressed={to_string(@list_mode == :location)}
              class={[
                "list-place pointer-events-auto min-w-0 cursor-pointer truncate outline-none",
                "transition-colors",
                "text-(length:--sub-type) tracking-(--sub-track) focus-visible:underline",
                tag_ink(@list_mode == :location)
              ]}
            >
              {String.upcase(@box_place)}
            </button>

            <%!-- THE COUNT AND ITS WORD ARE ONE PRESS, and they stay adjacent
                 inside one button for a reason beyond tidiness: this is what a
                 reader parses as a single fact — "four relationships" — and
                 splitting it across two controls would offer two answers to a
                 question with one. --%>
            <button
              type="button"
              phx-click="scope_box"
              aria-pressed={to_string(@list_mode == :people)}
              class={
                [
                  "list-scope pointer-events-auto flex shrink-0 cursor-pointer items-baseline gap-1.5",
                  "outline-none",
                  "text-(length:--sub-type) tracking-(--sub-track) transition-colors",
                  "focus-visible:underline",
                  # QUIETER THAN THE PLACE, and deliberately the quietest thing on
                  # the page. Two captions at one weight are two things asking to be
                  # read before the list under them; the place is the one that
                  # changes what you are looking at, so it is the one that keeps a
                  # voice. This is a fact you glance at, not a control you hunt for.
                  "text-neutral-300 hover:text-neutral-400",
                  "dark:text-neutral-700 dark:hover:text-neutral-500"
                ]
              }
            >
              <span class="font-bold">
                {(@scope == "SCOPED" && @box_counts.scopes) || @box_counts.unscopes}
              </span>
              <span>{(@scope == "SCOPED" && "RELATIONSHIPS") || "PEOPLE"}</span>
            </button>

            <%!-- ── WHETHER THE LIST MOVES ON ITS OWN ──────────────────────
               LIVE IS A CHOICE, and it belongs beside the other two facts about
               the list because it is one: where you are, which population, and
               whether it comes to you.

               OFF IT COUNTS RATHER THAN QUEUING SILENTLY. A held list that said
               nothing would be a list quietly going stale; the number is the
               offer to catch up, and pressing it is the reader choosing the
               moment the ground moves under them. --%>
            <button
              type="button"
              phx-click="toggle_live"
              aria-pressed={to_string(@live)}
              class={[
                "list-live pointer-events-auto shrink-0 cursor-pointer outline-none",
                "text-(length:--sub-type) tracking-(--sub-track) transition-colors",
                "focus-visible:underline",
                (@live && "text-neutral-300 hover:text-neutral-400 dark:text-neutral-700") ||
                  "text-neutral-400 hover:text-neutral-500 dark:text-neutral-500"
              ]}
            >
              {(@live && "LIVE") || "PAUSED"}
            </button>

            <button
              :if={!@live && @waiting > 0}
              type="button"
              phx-click="catch_up"
              class={[
                "list-waiting pointer-events-auto shrink-0 cursor-pointer px-2 py-0.5 outline-none",
                "text-(length:--sub-type) tracking-(--sub-track) transition-colors",
                "bg-secondary-500/20 text-secondary-700 hover:bg-secondary-500/30",
                "dark:bg-secondary-400/25 dark:text-secondary-200"
              ]}
            >
              {@waiting} NEW
            </button>

            <%!-- THE WAY OUT THAT CHANGES NOTHING, and it travels with the control
                 it undoes. Both tags COMMIT something when pressed, and the roll
                 of places has no empty state to escape to — the band always holds
                 a country, or reads WORLD, and WORLD is itself a choice. So
                 leaving without choosing needs a door of its own. --%>
            <button
              :if={@list_mode == :location}
              type="button"
              phx-click="cancel_place"
              aria-label="Leave the world without changing place"
              class="pointer-events-auto cursor-pointer text-neutral-400/50 transition-colors outline-none hover:text-neutral-500 focus-visible:text-neutral-500 dark:text-neutral-500/60 dark:hover:text-neutral-400"
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

          <div
            id={"scopes-scroll-#{@list_mode}-#{@scope}"}
            phx-hook="Scopes"
            phx-mounted={JS.ignore_attributes(["class"])}
            class="scopes-scroll h-full w-(--list-w) overflow-y-auto overscroll-contain"
          >
            <%!-- Lead and trail are what let the first and last row REACH the
                   band. The lead is one row DEEPER than the band, so the list
                   opens with the band standing empty — the unselected state.
                   They are MEASURED, so they are the hook's to write and the
                   server's to leave alone — see the note above. --%>
            <ul phx-mounted={JS.ignore_attributes(["style"])}>
              <%!-- SOMEBODY IS ARRIVING. It holds the row's exact shape for the
                   couple of seconds between the news and the list taking it in,
                   so the movement is announced before it happens rather than
                   simply happening. An empty pause would be the same jolt with
                   a delay on it. --%>
              <li
                :if={@landing && @list_mode == :people}
                class="scopes-item scopes-landing flex h-(--row-h) items-center px-(--list-pad)"
                aria-hidden="true"
              >
                <span class="skeleton block h-[0.9em] w-40"></span>
              </li>
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
                data-letter-kind={item[:frame] || "empty"}
                data-media={item[:media]}
                data-body={item[:body]}
                class={
                  [
                    "scopes-item flex cursor-pointer whitespace-nowrap",
                    # JUST ARRIVED. Sage, which on this surface reports rather
                    # than asks — terracotta is for the one thing wanting
                    # something from you, and somebody turning up wants nothing.
                    # It fades on its own; a row that stayed marked would be
                    # permanently new, which is the same as unmarked.
                    # `item[:id]`, NOT `item.id`. The same scroller carries a
                    # roll of COUNTRIES, and a country has a name and no id —
                    # the dotted form raises on every one of them.
                    item[:id] && item[:id] == @fresh && "is-fresh",
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
                <%!-- ── THE ROW SWIPES ────────────────────────────────────
                       A HORIZONTAL SCROLLER WITH TWO SNAP POINTS, and no
                       JavaScript at all: the row is one page and the action is
                       the next, `snap-mandatory` makes it rest on one or the
                       other, and the browser does the dragging, the momentum and
                       the rubber-banding for free. A hand-written swipe would be
                       three of those four re-invented worse.

                       overscroll-x-contain is what keeps a sideways drag from
                       becoming a browser back-gesture, and `touch-pan-*` is what
                       keeps it from fighting the VERTICAL list it sits inside —
                       two scrollers at right angles in the same pixel, each
                       needing the other to keep out of its axis. --%>
                <div class="row-swipe flex h-full w-full snap-x snap-mandatory overflow-x-auto overscroll-x-contain">
                  <div class="flex h-full w-full shrink-0 snap-start items-center px-(--list-pad)">
                    <div class="flex min-w-0 flex-1 items-start">
                      <%!-- NOTHING ON THE LEFT. It held the last letter's kind
                           as a mark, then briefly a round number and an unread
                           count — `2·0`, which is a database row wearing a
                           serif. Neither is what you are scanning a list of
                           people for. The FLOW on the right is the row's one
                           mark, and it says the only thing a glance needs: is
                           anything waiting, and did the last word go out or
                           come in. --%>
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
                          <%!-- AND NOT THEIR OTHER NAME EITHER. "MUM SARAH" is
                               two labels for one person on one line, which reads
                               as a headline over a byline. One name. --%>
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
                        <%!-- NOTHING UNDER THE NAME. It carried the round's
                             name, and before that the age of the last letter,
                             and either one turns the list into a FEED — a column
                             of headlines with people's names attached, read
                             top-down for content. This list is people-first;
                             what the round is about lives in the boxes beside
                             the band, which answer one person at a time because
                             you chose them. --%>
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
                  </div>

                  <%!-- WHAT THE SWIPE UNCOVERS: TWO ACTS, NOT ONE.

                       It offered exactly one — SCOPE for a stranger, WRITE for
                       somebody you hold — on the reasoning that each row has one
                       thing that applies to it. That was wrong in both
                       directions. A scoped person had no way to be UNSCOPED at
                       all, which made scoping the one decision here you could
                       not take back; and a stranger could not be written to,
                       which is a rule about who may write to whom rather than a
                       fact about what a row is, and one this app has not decided
                       yet.

                       SO: THE TIE, AND THE LETTER. The first changes what you
                       are to each other and says which change is outstanding —
                       see `row_act/1`. The second is always the same word.

                       TWO THINGS ON ONE PRESS: the server is told who, and the
                       hook opens the room. The panel's open state lives in the
                       browser and the target lives in the process, so neither
                       can do this alone. --%>
                  <div :if={@list_mode == :people} class="flex h-full shrink-0 snap-start">
                    <%!-- UNSCOPING IS NOT DONE ON ONE PRESS. Everything else
                         behind this swipe opens a room and asks something; this
                         one would act, immediately and irreversibly, on a
                         control you reach by dragging — which is exactly the
                         gesture a thumb makes by accident on a moving list. So
                         it ARMS instead, and the toast asks for the second
                         press. The reference calls this the irreversible-X law
                         and applies it everywhere a press cannot be taken back.

                         `phx-click` stays on it either way: the confirmation
                         lives in the browser because it is about a gesture, and
                         the hook stops the first press from reaching here. --%>
                    <button
                      type="button"
                      data-open-room={(item[:label] && "") || "scope"}
                      data-unscope={(item[:label] && item.id) || nil}
                      phx-click={(item[:label] && "unscope") || "pick_person"}
                      phx-value-id={item.id}
                      phx-value-act="scope"
                      class={
                        [
                          "row-scope flex h-full cursor-pointer items-center px-8",
                          "text-(length:--sub-type) tracking-(--sub-track) transition-colors",
                          # UNSCOPING WEARS THE COLOUR, and it is the only thing
                          # behind this swipe that does. Terracotta on this surface
                          # means "look here" — it is on an unread mark and on the
                          # one button in a room that commits — and undoing a tie
                          # two people agreed to is the only act here that deserves
                          # it. Both themes, because a wash that exists in one is
                          # a button that disappears in the other.
                          (item[:label] &&
                             "bg-primary-600/15 text-primary-700 hover:bg-primary-600/25 dark:bg-primary-500/25 dark:text-primary-200 dark:hover:bg-primary-500/35") ||
                            "bg-neutral-150 text-neutral-600 hover:bg-neutral-200 hover:text-neutral-800 dark:bg-neutral-800 dark:text-neutral-200 dark:hover:bg-neutral-700 dark:hover:text-neutral-50"
                        ]
                      }
                    >
                      {row_act(item)}
                    </button>

                    <%!-- WRITING IS OFFERED TO EVERYONE. Whether a letter to
                         somebody who has not scoped you should arrive is a
                         question about permission, and this app has not answered
                         it yet — hiding the button was answering it by accident,
                         and answering it "never". --%>
                    <button
                      type="button"
                      data-open-room="write"
                      phx-click="pick_person"
                      phx-value-id={item.id}
                      phx-value-act="write"
                      class="row-scope flex h-full cursor-pointer items-center bg-neutral-150 px-8 text-(length:--sub-type) tracking-(--sub-track) text-neutral-600 transition-colors hover:bg-neutral-200 hover:text-neutral-800 dark:bg-neutral-800 dark:text-neutral-200 dark:hover:bg-neutral-700 dark:hover:text-neutral-50"
                    >
                      WRITE
                    </button>
                  </div>
                </div>
              </li>
            </ul>
          </div>

          <%!-- WHAT AN EMPTY LIST SAYS. A place with nobody in it used to be a
               blank column, which on a surface whose whole content IS the list
               is indistinguishable from a page that failed to load. It reads at
               the band, because that is where an answer appears, and it names
               the place — the reason the list is empty is almost always that
               you are standing somewhere you know nobody, and the way out is
               the place box directly above it. --%>
          <div
            :if={@list == []}
            class="pointer-events-none absolute inset-x-0 top-[34%] flex -translate-y-1/2 flex-col gap-2 px-(--list-pad)"
          >
            <p class="text-(length:--row-type) tracking-(--row-track) text-neutral-300 dark:text-neutral-700">
              {empty_line(@scope)}
            </p>
            <p class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-250 dark:text-neutral-750">
              {empty_hint(@scope, @box_place)}
            </p>
          </div>

          <%!-- ── THE TRAILING BOXES ─────────────────────────────────────────
               THREE BOXES ON ONE LINE, and between them they answer the only
               question worth asking about the person under the band: what are
               they doing, how are they, and what have they sent.

               THEY ANSWER THE BAND — and until now only one of them did. The
               first two were WHERE you are and WHICH population you are looking
               at, which are facts about the LIST: the same whichever name has
               scrolled in. They read as part of this cluster and answered to
               nothing in it. They are a caption at the head of the list now, and
               what is left here really is aimed.

               WHY THIS AND NOT A ROLL OF NAMES. Showing that six people are
               around is a museum — objects to look at, nothing to join. What
               makes presence worth having is the second half: they are here AND
               they are watching something, reading something, out somewhere. The
               boxes are that second half, which is why they took the rail.

               WORDS, NOT ICONS, AND THE SET IS THE ARGUMENT. `heartbroken` and
               `low` are different things and no pair of drawings says which is
               which; at the size a mark reads on this row they collapse into the
               same face, and that is exactly the distinction worth showing. See
               `Peoplemedia.Around` for both vocabularies.

               SIDE BY SIDE AND FLUSH, in one row, with the letter box last so it
               keeps the rail's right edge — the app's right bound, which nothing
               crosses.

               FIXED WIDTHS, AND EMPTY ONES KEEP THEIR SLOT. Most people are
               around silently: here, and saying nothing about it. Collapsing the
               two empty boxes would slide the letter box sideways on every
               settle, so an empty box goes invisible rather than going away and
               the one box that is always the same object stays where the eye
               left it.

               NO BRACKETS ON THE FIRST TWO. Brackets on this surface mean
               AIMING, and these are already aimed by the band — the letter box
               wears them because it holds a thing you can open, and these hold a
               word. --%>
          <%!-- IT FILLS WHAT IS BESIDE THE BAND. Three fixed boxes left a strip
               of empty rail on a narrow desktop while the doing box — the only
               one carrying somebody's own words — truncated inside ten rems. The
               two short answers keep their slots; the one with no fixed length
               takes the rest. --%>
          <%!-- A GROUND WHILE THE FORM IS IN IT, because the doing box grows
               downward as you write and the names are directly underneath. --%>
          <div class={[
            "scope-boxes pointer-events-none z-20 flex items-start gap-3",
            @going && "bg-light-50 dark:bg-dark-950"
          ]}>
            <%!-- THE SAME THREE BOXES, ASKING. Going round puts the questions
                 exactly where the answers will be, so nothing moves between
                 filling the form in and reading it back. --%>
            <%!-- THE BOX IS THE FIELD. It had a DOING label over a one-line
                 input tucked underneath, which is a caption and a control where
                 there should be one thing you can write in — and the label named
                 what the box obviously was. The placeholder does that job and
                 leaves when you answer it.

                 A TEXTAREA, NOT AN INPUT, and that is not a detail. Return in a
                 single-line input SUBMITS THE FORM, so trying to break a line
                 sent the round and shut the form — the one keystroke somebody
                 reaches for while writing was the one that ended it. A textarea
                 takes the newline and grows into it; the check at the foot is
                 the only thing that sends. --%>
            <div
              :if={@going}
              class={[
                "around-box pointer-events-auto flex min-h-(--band-h) min-w-0 flex-1 items-center",
                "overflow-hidden px-4 bg-neutral-400/10 dark:bg-neutral-300/15"
              ]}
            >
              <%!-- `phx-update="ignore"`, AND WITHOUT IT THE FIELD FOUGHT BACK.
                   The server held what was typed and rendered it into the
                   textarea's CONTENT, so every keystroke's patch rewrote the
                   node somebody was typing into — newlines were normalised away
                   and spaces went missing mid-word. The letter composer has the
                   same note for the same reason.

                   SO THE FIELD IS THE BROWSER'S until it is sent. It survives
                   the picker opening because an ignored node is not re-rendered,
                   and the submit posts whatever is in it. Nothing else needs to
                   read it while it is being written. --%>
              <textarea
                id="doing-field"
                phx-update="ignore"
                form="round-form"
                name="doing"
                rows="1"
                maxlength={Rounds.doing_limit()}
                placeholder="WHAT ARE YOU UP TO?"
                class="doing-field max-h-(--doing-max) w-full resize-none overflow-hidden bg-transparent py-4 text-(length:--row-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
              ></textarea>
            </div>

            <%!-- AND SO DOES THE MOOD BOX. `—` is the placeholder and the
                 answer replaces it, the same way the doing box works one step to
                 the left. A label reading MOOD over a dash was two lines to say
                 nothing. --%>
            <button
              :if={@going}
              type="button"
              phx-click="pick_open"
              phx-value-which="mood"
              data-family={Rounds.family_of(@round_pick.mood)}
              aria-label="How are you"
              class={[
                "around-box mood-box pointer-events-auto flex min-h-(--band-h) w-(--mood-w)",
                "shrink-0 cursor-pointer items-center justify-center overflow-hidden px-4",
                "outline-none transition-colors",
                !Rounds.family_of(@round_pick.mood) &&
                  "bg-neutral-400/10 hover:bg-neutral-400/20 dark:bg-neutral-300/15 dark:hover:bg-neutral-300/25"
              ]}
            >
              <span class={[
                "w-full truncate text-center text-(length:--row-type) tracking-(--row-track)",
                (@round_pick.mood && "text-light-900 dark:text-dark-100") ||
                  "text-neutral-300 dark:text-neutral-700"
              ]}>
                {String.upcase(@round_pick.mood || "—")}
              </span>
            </button>

            <%!-- THE FRAME'S PLACE, and it is empty because a frame is CAPTURED
                 and there is nothing to capture with yet. It pulses rather than
                 sitting blank: an unfilled round frame is somebody here with
                 nothing to show, which is a real state and the commonest one. --%>
            <%!-- THE WHOLE BOX BREATHES, not a dot inside it. A small mark
                 pulsing in the middle of a still square reads as a status light
                 bolted to a container; the frame IS the thing that is empty, so
                 the frame is what should say so. It is also what a captured one
                 will fill, and a box that changed shape when it got contents
                 would be two objects. --%>
            <div
              :if={@going}
              aria-label="A frame, when there is one"
              class="around-box presence-box pointer-events-auto relative size-(--band-h) shrink-0 bg-primary-600/15 dark:bg-primary-500/20"
            >
            </div>

            <%!-- ONE: WHAT THEY ARE DOING. The kind of thing above, quiet, in
                 the same small tracked voice the age under a name uses; the
                 THING itself below, at the count's size. That order is the way
                 it is read — "watching" tells you what sort of answer is coming
                 and "the witchers" is the answer — and it is the only place on
                 this surface where somebody's own typing is set large. --%>
            <div
              :if={!@going}
              phx-mounted={JS.ignore_attributes(["class"])}
              role="button"
              tabindex="0"
              data-opens="what they are doing"
              aria-label="Expand what they are doing"
              class={[
                "around-box doing-box pointer-events-auto relative flex h-(--band-h) min-w-0",
                "flex-1 cursor-pointer flex-col justify-center gap-1 overflow-hidden px-4",
                "bg-neutral-400/10 dark:bg-neutral-300/15"
              ]}
            >
              <%!-- TWO READINGS OF ONE FACT. Closed it truncates, because the
                   box is ten rems wide and a doing is somebody's own typing;
                   open it wraps and has the whole rail. The class that switches
                   between them is the CLIENT'S — opening a box is a gesture in
                   one browser, which is the same reason the letter box's is. --%>
              <div class="around-brief flex flex-col gap-1 overflow-hidden">
                <span
                  :if={@current[:round][:doing]}
                  class="truncate text-(length:--sub-type) tracking-(--sub-track) text-neutral-500 dark:text-neutral-400"
                >
                  {String.upcase(@current.round.doing)}
                </span>
                <span
                  :if={@current[:round][:about]}
                  class="truncate text-(length:--row-type) leading-none tracking-(--row-track) text-light-900 dark:text-dark-100"
                >
                  {String.upcase(@current.round.about)}
                </span>
              </div>
              <div class="around-full flex-col justify-center gap-3 overflow-y-auto text-left">
                <span
                  :if={@current[:round][:doing]}
                  class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-500 dark:text-neutral-400"
                >
                  {String.upcase(@current.round.doing)}
                </span>
                <span
                  :if={@current[:round][:about]}
                  class="text-(length:--row-type) leading-tight tracking-(--row-track) text-light-900 dark:text-dark-100"
                >
                  {String.upcase(@current.round.about)}
                </span>
              </div>
            </div>

            <%!-- TWO: HOW THEY ARE, and the one place on this surface that
                 carries a colour of its own.

                 THE BAND COULD NOT HAVE IT. Tinting the selection by mood was
                 the obvious move and it is the one thing that cannot work: the
                 band already uses colour to say THIS IS THE CHOSEN ONE, so a
                 second meaning on the same property leaves neither readable —
                 scroll to somebody and the wash goes amber, and there is no way
                 to tell whether the amber is the selection or the person.

                 A BOX THAT MEANS ONLY MOOD CANNOT LIE. It is a dedicated object,
                 it sits nowhere near the unread marks, and it puts the colour
                 directly beside the word — which is how a colour language is
                 learned in the first place.

                 THE WORD KEEPS THE ORDINARY INK. The wash carries the hue and
                 the hue never reaches full strength, because the moment a mood is
                 as loud as terracotta, terracotta stops meaning "look here". --%>
            <div
              :if={!@going}
              phx-mounted={JS.ignore_attributes(["class"])}
              role="button"
              tabindex="0"
              data-opens="how they are"
              aria-label="Expand how they are"
              class={[
                "around-box mood-box pointer-events-auto relative flex h-(--band-h) w-(--mood-w)",
                "shrink-0 cursor-pointer items-center justify-center overflow-hidden px-3",
                !@current[:round][:family] && "bg-neutral-400/10 dark:bg-neutral-300/15"
              ]}
              data-family={@current[:round][:family]}
            >
              <span
                :if={@current[:round][:mood]}
                class="around-brief truncate text-(length:--sub-type) tracking-(--sub-track) text-light-900 dark:text-dark-100"
              >
                {String.upcase(@current.round.mood)}
              </span>
              <%!-- OPEN, IT NAMES THE FAMILY TOO. The colour belongs to the
                   family and the word to the feeling, so a box that only ever
                   showed the word left its own hue unexplained — you would
                   learn it eventually and never once be told. --%>
              <div class="around-full flex-col items-center justify-center gap-3 text-center">
                <span class="text-(length:--count-type) leading-none tracking-(--row-track) text-light-900 dark:text-dark-100">
                  {String.upcase(@current[:round][:mood] || "")}
                </span>
                <span class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-500 dark:text-neutral-400">
                  {String.upcase(@current[:round][:family] || "")}
                </span>
              </div>
            </div>

            <%!-- THREE: THE LETTER BOX — the last letter the settled person
                 sent YOU, and the reason this surface exists. It is the only
                 box here that is an ANSWER rather than a control, which is why
                 it is the only one that comes and goes and the only one wearing
                 brackets.

                 It was called the frame, which named the drawing rather than
                 the contents, and it held whatever the row's newest letter was
                 — as often your own, so the box could answer you with your own
                 words. It holds the last INCOMING one now, and holds nothing at
                 all when there is none: see `Directory.letterbox/1`, where a
                 stranger and a one-sided correspondence come out the same way,
                 because you cannot be shown a letter that was never written to
                 you and you cannot be shown one written to somebody else.

                 ITS WHOLE STATE IS ITS CLASS, and the class is the client's.
                 Which letter is in the box depends on where the list has
                 settled, which is a fact about a scroll position in one browser
                 — the server renders `is-empty` because that is all it can
                 honestly say, and the hook writes the truth over it.

                 SO THE CLASS IS EXEMPT, and leaving it out cost the box twice
                 over. A patch reset it to `is-empty`, so the letter the hook had
                 just put there vanished on the very next round trip — which is
                 the same round trip the settle itself causes, so the box flashed
                 once and went. Before the empty box was HIDDEN that read as a
                 blank square and was survivable; once an empty box meant "no
                 letter, show nothing", it read as the box being broken.

                 The two MEDIA elements inside carry their own state separately
                 (see the Media hook) because an attribute exemption cannot help
                 a playing clip. --%>
            <div
              :if={@list_mode == :people && !@going}
              id="letterbox"
              phx-mounted={JS.ignore_attributes(["class"])}
              role="button"
              tabindex="0"
              aria-label="Expand the letter"
              class="letterbox is-empty pointer-events-auto relative flex size-(--band-h) shrink-0 cursor-pointer items-center justify-center p-2 transition-[opacity,width,height,padding] duration-300"
            >
              <%!-- The screen is inset from the frame so the brackets bracket the
                   picture rather than cropping it, and square on every corner —
                   a screen has corners, and rounding them makes it a widget. --%>
              <div class="letterbox-screen relative h-full w-full overflow-hidden bg-primary-600/15 dark:bg-primary-500/20">
                <%!-- THE WORDS, and the one thing on this surface set in the
                     case it was written in. Everything else is the app talking
                     and is therefore in capitals; a letter is a person talking,
                     and putting somebody's own sentence in capitals is the app
                     raising its voice on their behalf.

                     Clipped rather than shortened: at 56px there is room for a
                     few words, and the box is a glimpse — pressing it is what
                     asks for the rest. --%>
                <span class="letterbox-words"></span>
                <video
                  id="letterbox-video"
                  phx-hook="Media"
                  class="letterbox-video h-full w-full object-cover"
                  playsinline
                  preload="metadata"
                >
                </video>
                <%!-- Sits ON the screen, covering it: after a clip ends the
                     screen is the only thing there, and a control tucked into
                     the corner of a 45px square is a target nobody can hit. --%>
                <button
                  type="button"
                  class="letterbox-restart absolute inset-0 hidden items-center justify-center bg-light-950/15 text-light-50 transition-colors hover:bg-light-950/30 dark:bg-dark-950/25 dark:hover:bg-dark-950/40"
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
              <audio id="letterbox-audio" phx-hook="Media" class="letterbox-audio" preload="none">
              </audio>
            </div>
          </div>

          <%!-- BAND AND FRAME ARE ONE ROW, so the two can never fall out of line.
               The band answers "which one", the frame answers "and what are they
               sending". Both appear only on a settled selection. --%>
          <%!-- ── GOING ROUND, IN PLACE ──────────────────────────────────
               IT TAKES THE BAND'S LINE, and the list goes on underneath. That is
               the whole reason it is not a panel: a room over the page would
               hide the people the round exists to reach, and it would cost a
               full screen to ask four short questions.

               IT IS THE SHAPE OF WHAT IT MAKES, and now it is the SAME OBJECTS
               IN THE SAME PLACES. The bar replaces the band; the three boxes on
               the rail become the three that ask. They were in a row of their
               own beneath the bar, which meant the form and the thing it
               produces sat in different places and the page reflowed on every
               press. One position, two states.

               THE FORM IS THE BAR ALONE. Its controls live in the cluster and in
               the foot, which HTML allows through `form=` — a control belongs to
               a form by id, wherever it stands. --%>
          <form
            :if={@going}
            id="round-form"
            phx-change="round_change"
            phx-submit="round_send"
            class="round-form list-box pointer-events-auto absolute top-(--list-top) left-0 z-30 flex min-h-(--band-h) items-center"
          >
            <%!-- OPAQUE, AND THAT IS THE WHOLE OF THE FIX. It wore the band's
                 own wash — `bg-primary-600/15` — and the band is TRANSLUCENT on
                 purpose so the row passing under it reads through. Here the row
                 underneath is whoever happened to be settled when you pressed
                 the plus, so your own name sat on top of theirs: FUNMI over
                 IBRAHIM, two names in one line of text. Clearing the selection
                 server-side did not help, because where the list is SCROLLED to
                 is the browser's and the row is still physically there. Same
                 colour, composited once — see .self-box for the same trick and
                 the same reason.

                 THE BAR SAYS WHO IS GOING ROUND, and it is not a field. It
                 held the round's NAME, which was the same thought the doing box
                 was asking for one step to the right — so the name has gone and
                 the doing box is where you type. What is left in the band's
                 place is the one thing a round always has: a person. It is the
                 shape their row will take the moment it is sent. --%>
            <span class="truncate text-(length:--row-type) tracking-(--row-track) text-light-900 dark:text-dark-100">
              {String.upcase((@current_person && @current_person.name) || "")}
            </span>
            <input type="hidden" name="mood" value={@round_pick.mood || ""} />
          </form>

          <%!-- ── WHAT A BOX OPENS ONTO ──────────────────────────────────
               MOODS COME IN THEIR FAMILIES, one row each, coloured by the family
               rather than by the word. Forty-eight hues would be a language
               nobody could learn; seven is one you pick up by using it, and
               inside a family the words differ by intensity — annoyed,
               irritated, furious — so the colour says the weather and the word
               says the temperature.

               IT COVERS THE LIST while it is open, and that is the one moment
               this surface is allowed to: you are choosing, and the names
               underneath are not the question. --%>
          <div
            :if={@going && @picker}
            class="round-picker absolute inset-x-0 top-(--list-top) z-40 mt-(--picker-top) max-h-[55vh] overflow-y-auto bg-light-50/95 py-4 dark:bg-dark-950/95"
          >
            <div :if={@picker == "mood"} class="flex flex-col gap-5">
              <div :for={{family, words} <- Rounds.mood_families()} class="flex flex-col gap-2">
                <p class="px-(--list-pad) text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
                  {String.upcase(family)}
                </p>
                <div class="flex flex-wrap gap-2 px-(--list-pad)">
                  <button
                    :for={mood <- words}
                    type="button"
                    phx-click="pick"
                    phx-value-which="mood"
                    phx-value-word={mood}
                    data-family={family}
                    class={[
                      "mood-word cursor-pointer px-3 py-2 text-(length:--sub-type) outline-none",
                      "tracking-(--sub-track) text-light-900 transition-colors dark:text-dark-100",
                      @round_pick.mood == mood && "is-picked"
                    ]}
                  >
                    {String.upcase(mood)}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div
            id="bar"
            phx-hook="Bar"
            class={
              [
                "bar pointer-events-none absolute inset-x-0 top-(--band-top) flex -translate-y-1/2 items-center",
                @mode in [:open, :self] && "is-picked",
                # THE FORM HAS THE LINE. Two things on it would be two answers to
                # "what is at the top of this list".
                @going && "invisible"
              ]
            }
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
                :if={@subject}
                class="focus-name flex min-w-0 flex-1 items-baseline overflow-hidden whitespace-nowrap text-(length:--row-type) tracking-(--row-track) text-light-900 dark:text-dark-100"
              >
                {String.upcase(@subject[:label] || @subject[:name])}
                <span
                  :if={@subject[:label]}
                  class="ml-3 text-neutral-400/70 dark:text-neutral-500/70"
                >
                  {@subject[:name]}
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
        :if={@subject}
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
              <%!-- WHAT THEY ARE DOING, ON THE PANEL'S OWN LINE.
                   THE BOXES CANNOT REACH IN HERE. They answer the BAND, and
                   opening a panel is exactly the act that takes the band away —
                   so without this, walking into somebody's page LOSES the one
                   thing the rail had just told you about them. It is worse on
                   your own page, which has no row in the list at all: your
                   around would be a thing you could set and never once see.

                   BESIDE THE HEADING, NOT ABOVE THE LETTERS. It belongs to the
                   person the panel is about rather than to the correspondence
                   under it, which is the same reason it is on this line and in
                   this voice — the small tracked one every caption here uses. --%>
              <p class="absolute top-6 left-0 z-20 flex items-center gap-4 text-(length:--sub-type) tracking-[0.22em] text-neutral-400 dark:text-neutral-500">
                <span>LETTERS</span>
                <span
                  :if={@subject[:round][:doing] || @subject[:round][:mood]}
                  class="panel-around flex items-center gap-3 px-3 py-1 text-light-900 dark:text-dark-100"
                  data-family={@subject[:round][:family]}
                >
                  <span :if={@subject[:round][:mood]}>{String.upcase(@subject.round.mood)}</span>
                  <span
                    :if={@subject[:round][:doing]}
                    class="text-neutral-500 dark:text-neutral-400"
                  >
                    {String.upcase(
                      [@subject.round.doing, @subject.round[:about]]
                      |> Enum.reject(&(&1 in [nil, ""]))
                      |> Enum.join(" · ")
                    )}
                  </span>
                </span>
              </p>

              <%!-- THE BOX — the list's own selection box kept whole: the wash,
                   the brackets, the "--" for an empty band. What is different is
                   that its job is not delegated to a frame off to the side; the
                   box IS the player. A voice fills it as a bar, a face shows in
                   it. It sits BEHIND the rows (z-0 to their z-10) so the chosen
                   row's name reads over whatever is playing, and the brackets,
                   being at the corners, clear the words entirely. --%>
              <div
                id={"stage-#{@panel_key}"}
                class="stage w-full px-(--list-pad) lg:w-(--list-w) pointer-events-none absolute top-[calc(var(--panel-row-h)*1.5)] left-0 z-0 flex h-(--panel-row-h) -translate-y-10 items-center overflow-hidden bg-primary-600/15 dark:bg-primary-500/20"
              >
                <video
                  id={"stage-video-#{@panel_key}"}
                  phx-hook="Media"
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
                <audio
                  id={"stage-audio-#{@panel_key}"}
                  phx-hook="Media"
                  class="stage-audio"
                  preload="none"
                >
                </audio>
              </div>

              <%!-- Lead and trail here are set by the hook, not the markup, so
                   the list rests unselected and every row can still reach the
                   band. The same two client-owned attributes as the list
                   outside, exempted for the same reason — see the long note on
                   the scroller above. The Tailwind padding on the ul is the
                   pre-measurement estimate the hook then replaces; without the
                   exemption a patch reverted to it and the letters jumped. --%>
              <div
                id={"panel-scroll-#{@panel_key}"}
                phx-hook="Panel"
                phx-mounted={JS.ignore_attributes(["class"])}
                class="panel-scroll relative z-10 h-full overflow-y-auto overscroll-contain"
              >
                <ul
                  phx-mounted={JS.ignore_attributes(["style"])}
                  class="pt-[calc(34vh+4rem)] pb-[30vh]"
                >
                  <li
                    :for={letter <- @subject.letters}
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
                  <%!-- `frame`, NOT `letterbox`, and the difference was a crash
                       waiting for the day presence became real. `Directory`
                       merges `letterbox(letters)` into the row, which adds
                       `frame`/`media`/`body` — there has never been a
                       `letterbox` key on it. Nothing raised only because `@live`
                       filters on a state nothing ever set, so this markup had
                       never once been rendered. A rename is not a safe operation
                       on a key nothing exercises. --%>
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
