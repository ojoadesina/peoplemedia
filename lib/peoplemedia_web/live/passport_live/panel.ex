defmodule PeoplemediaWeb.PassportLive.Panel do
  @moduledoc """
  THE PASSPORT, inside the FAB panel's passport room.

  A LiveView of its own rather than more assigns on the surface: this is five
  steps of form state and none of it is IndexLive's business — that file's own
  moduledoc says it is about the surface and nothing else. The panel registry
  knows only that there is a room called "passport"; what happens in it is this
  process.

  ## THE THREE MODES

      welcome  → two doors: request one, or check in with the one you have.
      join     → name · words · code · save them · country   (five steps)
      checkin  → name and one word · code                    (two steps)

  ## WHY SIGNING IN LOOKS LIKE THIS

  Ported whole, and worth restating because it is not a password. Your bank
  holds one-time WORDS; checking in spends one. A word is only burned when the
  code is right too, so a word someone reads over your shoulder is useless to
  them and costs you nothing when they try it. The code is the constant second
  factor and never changes; the words run down, and topping them up is the
  recovery story. There is no email in any of it.

  ## COUNTRY, AND NOTHING FINER

  The reference asked the browser for coordinates and put them through a
  geocoder to place you on a street. This asks which country you are in, from a
  list, because that is the only granularity this app has ever shown — and it
  costs no permission prompt, no third-party request, and no address sitting in
  a table waiting to leak.

  ## LEAVING BY THE FRONT DOOR

  A LiveView cannot set a cookie, so a successful join or check-in signs a
  short-lived token and redirects to `/passport/session`, which is a real
  request and can. See `PeoplemediaWeb.Plugs.PassportAuth`.
  """
  use PeoplemediaWeb, :live_view

  import PeoplemediaWeb.Launcher, only: [door: 1, foot: 1]

  alias Peoplemedia.{Directory, Identity, People, Repo}
  alias PeoplemediaWeb.Plugs.PassportAuth

  @words 3

  @impl true
  def mount(_params, session, socket) do
    {:ok, reset(socket, People.get_person(session["person_id"])), layout: false}
  end

  # ── THE ONE BRANCH ──────────────────────────────────────────────────────────
  # HOLDING A PASSPORT IS A DIFFERENT ROOM, not a different state of this one,
  # and it was simply missing: this room opened on REQUEST PASSPORT / CHECK IN
  # for everybody, so somebody already checked in was offered both doors to a
  # place they were standing in, and had no way to see or top up the word bank
  # that is the whole recovery story of the scheme.
  #
  # The branch is taken ONCE, at mount, from the session — the reference does
  # the same, and for the same reason: whether you are signed in is not
  # something that changes while you are looking at this.
  defp reset(socket, nil) do
    assign(socket,
      # Only ever drawn when detection has failed — see the country step.
      countries: Enum.map(Directory.countries(), & &1.name),
      mode: :welcome,
      person: nil,
      passport: nil,
      active: 0,
      total: 0,
      info: nil,
      step: 1,
      name: "",
      name_free: nil,
      words: List.duplicate("", @words),
      code: "",
      country: nil,
      geo: :pending,
      secret_id: nil,
      error: nil
    )
  end

  defp reset(socket, person) do
    passport = Identity.get_passport(person.id)

    assign(socket,
      countries: Enum.map(Directory.countries(), & &1.name),
      mode: :manage,
      person: person,
      passport: passport,
      # WORDS THAT ARE STILL SPENDABLE, over words ever issued. The percentage
      # on the row is the same number; both are shown because a bare percentage
      # does not tell you how many check-ins you have left, which is the actual
      # question.
      active: (passport && Enum.count(passport.secrets, &(&1.status == "active"))) || 0,
      total: (passport && Enum.count(passport.secrets)) || 0,
      info: nil,
      step: 1,
      name: "",
      name_free: nil,
      words: List.duplicate("", @words),
      code: "",
      country: nil,
      geo: :pending,
      secret_id: nil,
      error: nil
    )
  end

  # ── WHERE YOU ARE ───────────────────────────────────────────────────────────
  # The hook pushes three things and this answers all of them. The geocode
  # happens HERE rather than on the way out, so the person sees the country
  # named and can tell it is wrong before the passport is written.
  @impl true
  def handle_event("geo", %{"lat" => lat, "lng" => lng}, socket) do
    case Peoplemedia.Geo.reverse_geocode(lat * 1.0, lng * 1.0) do
      {:ok, %{country: country}} ->
        {:noreply, assign(socket, country: country, geo: :granted, error: nil)}

      # THE PERMISSION WAS GIVEN AND THE LOOKUP FAILED, which is a different
      # thing from being refused and reads differently: nothing about it is the
      # person's to fix, and trying again is genuinely worth doing.
      {:error, _} ->
        {:noreply, assign(socket, country: nil, geo: :unavailable)}
    end
  end

  def handle_event("geo_error", %{"code" => code}, socket) do
    {:noreply, assign(socket, country: nil, geo: (code == 1 && :denied) || :unavailable)}
  end

  # Taken back after being given. The place goes with it, or somebody could
  # withdraw the permission and still be placed on what it had already said.
  def handle_event("geo_lost", _params, socket) do
    {:noreply, assign(socket, country: nil, geo: :denied)}
  end

  def handle_event("retry_location", _params, socket) do
    {:noreply, socket |> assign(geo: :pending) |> push_event("request_location", %{})}
  end

  # ── TOPPING UP ──────────────────────────────────────────────────────────────
  # SPLIT ON WHITESPACE, because "add a few words" is one sentence and asking
  # for three fields would make it three. Lower-cased on the way in: a word is
  # checked case-insensitively everywhere else, and storing the shift key would
  # make it part of the secret without telling anyone.
  @impl true
  def handle_event("add_words", %{"words" => words}, socket) do
    list = words |> String.downcase() |> String.split(~r/[\s,]+/, trim: true)

    case Identity.add_secrets(socket.assigns.passport, list) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reset(socket.assigns.person)
         |> assign(info: "Added #{length(list)} word(s).")}

      {:error, reason} ->
        {:noreply, assign(socket, error: word_error(reason), info: nil)}
    end
  end

  # ── APPEARING, OR NOT ───────────────────────────────────────────────────────
  # ONE PRESS, NO CONFIRMATION, and that is the right asymmetry: going hidden is
  # instant because it is the safe direction, and coming back is the same press
  # because nobody should have to answer a dialogue to be seen again.
  #
  # IT TAKES EFFECT ON THE READ, not by deleting anything. `Around` filters
  # hidden people inside the query every surface goes through, so this is one
  # boolean and there is no state anywhere that can be left behind still showing.
  def handle_event("toggle_around", _params, socket) do
    person = socket.assigns.person

    case People.set_around_hidden(person, not person.around_hidden) do
      {:ok, updated} -> {:noreply, assign(socket, person: updated, error: nil)}
      {:error, _} -> {:noreply, assign(socket, error: "That did not go through.")}
    end
  end

  # ── THE TWO DOORS ───────────────────────────────────────────────────────────
  @impl true
  def handle_event("choose", %{"mode" => mode}, socket) when mode in ~w(join checkin) do
    {:noreply, assign(socket, mode: String.to_existing_atom(mode), step: 1, error: nil)}
  end

  # BACK IS ONE STEP, never all of them. The act steps out of the room; this
  # steps within it, and the two must not be the same gesture.
  def handle_event("back", _params, %{assigns: %{step: 1}} = socket) do
    {:noreply, assign(socket, mode: :welcome, error: nil)}
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: socket.assigns.step - 1, error: nil)}
  end

  # ── JOIN ────────────────────────────────────────────────────────────────────
  # THE NAME IS ALSO THE HANDLE, which is why it is checked as you type: a name
  # already taken is the one failure here that cannot be fixed at the end, and
  # finding out after choosing three words and a code would be a form throwing
  # away work you had already done.
  def handle_event("name", %{"name" => name}, socket) do
    {:noreply,
     assign(socket, name: name, name_free: Identity.handle_available?(name), error: nil)}
  end

  def handle_event("next", _params, %{assigns: %{mode: :join, step: 1}} = socket) do
    if socket.assigns.name_free,
      do: {:noreply, assign(socket, step: 2, error: nil)},
      else: {:noreply, assign(socket, error: name_error(socket.assigns.name))}
  end

  def handle_event("words", params, socket) do
    words = for i <- 0..(@words - 1), do: params["word_#{i}"] || ""
    {:noreply, assign(socket, words: words, error: nil)}
  end

  # EVERY RULE THE WRITE WILL APPLY, APPLIED HERE. This checked length and
  # uniqueness but not the FORMAT, and `Identity.create_passport/4` insists on
  # letters only — so a word with a digit or an apostrophe in it sailed through
  # this step and failed three screens later, at the one moment the passport was
  # actually being made. The error landed on the country step, about a field the
  # person could no longer see. A step that lets something through is a step
  # that lied.
  def handle_event("next", _params, %{assigns: %{mode: :join, step: 2}} = socket) do
    words = Enum.map(socket.assigns.words, &String.trim/1)

    cond do
      Enum.any?(words, &(String.length(&1) < 3)) ->
        {:noreply, assign(socket, error: "Three words, three letters or more.")}

      Enum.any?(words, &(!Regex.match?(~r/^[a-zA-Z]+$/, &1))) ->
        {:noreply, assign(socket, error: "Letters only — no numbers, spaces or marks.")}

      length(Enum.uniq(words)) != @words ->
        {:noreply, assign(socket, error: "Three different words.")}

      true ->
        {:noreply, assign(socket, words: words, step: 3, error: nil)}
    end
  end

  def handle_event("code", %{"code" => code}, socket) do
    {:noreply, assign(socket, code: String.slice(code, 0, 4), error: nil)}
  end

  def handle_event("next", _params, %{assigns: %{mode: :join, step: 3}} = socket) do
    if socket.assigns.code =~ ~r/^\d{4}$/,
      do: {:noreply, assign(socket, step: 4, error: nil)},
      else: {:noreply, assign(socket, error: "Four digits.")}
  end

  # Step 4 is the one screen that asks nothing — it shows the words back so they
  # can be written down. Passing through it is the acknowledgement.
  def handle_event("next", _params, %{assigns: %{mode: :join, step: 4}} = socket) do
    {:noreply, assign(socket, step: 5, error: nil)}
  end

  # THE MANUAL PICK, which exists only where detection could not answer. It is
  # not the question this step asks — the device already knows — it is the way
  # out of the step for somebody whose browser said no.
  def handle_event("country", %{"country" => country}, socket) do
    {:noreply, assign(socket, country: country, error: nil)}
  end

  # THE LAST STEP IS THE ONLY ONE THAT WRITES. Everything before it is held here
  # and nothing exists until the whole passport can be made at once — a person
  # row with no passport is a person nobody can be.
  def handle_event("next", _params, %{assigns: %{mode: :join, step: 5}} = socket) do
    %{name: name, words: words, code: code, country: country} = socket.assigns

    # ALL OR NOTHING. These were two writes with a `with` between them, so a
    # passport that failed to be made left the PERSON behind — a row with a name
    # and no way to be signed into. Trying again made a second one, and checking
    # in with either said "that name and word do not go together", because from
    # the passport's side neither existed. Two orphans and a person who cannot
    # get in is the worst outcome this flow has, and it was the likeliest one.
    result =
      Repo.transaction(fn ->
        with {:ok, person} <- People.create_person(%{name: name, country: country}),
             {:ok, _passport} <- Identity.create_passport(person, name, words, code) do
          person
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, person} -> {:noreply, check_in(socket, person)}
      {:error, reason} -> {:noreply, assign(socket, error: join_error(reason))}
    end
  end

  # ── CHECK IN ────────────────────────────────────────────────────────────────
  def handle_event("credentials", %{"name" => name, "word" => word}, socket) do
    case Identity.check_key(name, word) do
      {:ok, passport, secret_id} ->
        {:noreply, assign(socket, passport: passport, secret_id: secret_id, step: 2, error: nil)}

      {:error, :locked, seconds} ->
        {:noreply, assign(socket, error: locked_error(seconds))}

      {:error, _} ->
        {:noreply, assign(socket, error: "That name and word do not go together.")}
    end
  end

  def handle_event("verify", %{"code" => code}, socket) do
    case Identity.check_code(socket.assigns.passport, code, socket.assigns.secret_id) do
      {:ok, person} ->
        {:noreply, check_in(socket, person)}

      {:error, :locked, seconds} ->
        {:noreply, socket |> reset(nil) |> assign(mode: :checkin, error: locked_error(seconds))}

      {:error, _} ->
        {:noreply, assign(socket, error: "Wrong code.")}
    end
  end

  # A LiveView cannot set a cookie. Sign a short-lived token and go through the
  # session controller, which is a real request and can.
  defp check_in(socket, person) do
    token = PassportAuth.generate_session_token(socket, person.id)
    redirect(socket, to: ~p"/passport/session?#{[token: token]}")
  end

  defp name_error(name) do
    cond do
      String.trim(name) == "" ->
        "Pick a name."

      not Regex.match?(~r/^[a-z0-9]{2,10}$/, String.downcase(String.trim(name))) ->
        "Two to ten letters or numbers, nothing else."

      true ->
        "That name is taken."
    end
  end

  defp join_error(:nickname_taken), do: "That name is taken."
  defp join_error(:duplicate_secrets), do: "Three different words."
  defp join_error(:invalid_secret_format), do: "Words are letters only, three or more."
  defp join_error(:invalid_code_format), do: "Four digits."
  defp join_error(_), do: "That did not go through. Try again."

  defp locked_error(seconds) when seconds > 60, do: "Locked for #{div(seconds, 60)} minutes."
  defp locked_error(seconds), do: "Locked for #{seconds} seconds."

  defp geo_note(:granted), do: "This is where you are. It is the only thing we keep."
  defp geo_note(:denied), do: "Location is off for this site. Turn it on and try again."
  defp geo_note(:unavailable), do: "Could not work out where you are."
  defp geo_note(_), do: "Finding where you are…"

  defp word_error(:too_few_secrets), do: "Add at least one word."
  defp word_error(:too_many_secrets), do: "Too many at once — thirty is the limit."

  defp word_error(:invalid_secret_format),
    do: "Each word is three or more letters, and letters only."

  defp word_error(:duplicate_secrets), do: "Those must all be different from each other."
  defp word_error(_), do: "Could not add those."

  # ── THE SURFACE ─────────────────────────────────────────────────────────────
  # THE REFERENCE'S SHAPE, kept whole: a small tracked label saying where you
  # are, one big quiet field per thing being asked for, a hint under it, and a
  # grouped foot — a small back beside a larger forward — that submits the
  # step's form from outside it.
  #
  # TWO CHANGES, AND ONLY TWO. It is LEFT-ALIGNED, because every word on this
  # surface starts on one edge and a centred column in the middle of a
  # left-aligned app reads as a different app. And the buttons are FLAT: the
  # reference's rounded-full foot and rounded-md doors were the one place a
  # corner radius survived, and nothing here has one.
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <p :if={@error} class={[label_cls(), "pb-4 text-primary-600 dark:text-primary-500"]}>
        {String.upcase(@error)}
      </p>

      <%!-- ── MANAGE: you, and the one thing that runs out ────────────────
           WHAT A PASSPORT ROOM IS FOR ONCE YOU HAVE ONE. There is no password
           to change and no email to update — the only thing that can go wrong
           with this scheme is running out of words, and the only maintenance is
           adding more. So this room is a meter and a field.

           NO BACK AND NO FORWARD. Every other room here is a step in a flow;
           this one is a place you have arrived at, so the foot carries the way
           OUT and nothing else. The reference renders no foot at all here
           because its close button is global chrome outside every room — ours
           lives in the foot, so an empty foot is the same arrangement. --%>
      <div :if={@mode == :manage} class="flex flex-col items-center">
        <p class="text-(length:--count-type) tracking-(--row-track) text-light-900 dark:text-dark-100">
          {String.upcase(@person.name)}
        </p>
        <%!-- WHERE YOU ARE, ON A CHIP, and the only sky-coloured thing on the
             surface. Everything else here is terracotta or grey — terracotta
             means "this is asking for you", grey means "this is furniture" —
             and a place is neither. It is the one fact on this screen that is
             about the world rather than about you or the app, so it gets a
             colour that belongs to neither: the reference's landmark chip,
             flattened and given one hue instead of a generated one. --%>
        <span class="mt-4 inline-block bg-sky-500/15 px-4 py-2 text-(length:--sub-type) tracking-(--sub-track) text-sky-700 dark:bg-sky-400/20 dark:text-sky-300">
          {String.upcase(@person.country || "NOWHERE YET")}
        </span>

        <div :if={@passport} class="w-(--list-w) max-w-full pt-12">
          <p class={label_cls()}>WORD BANK · {@active} OF {@total}</p>
          <%!-- A BAR RATHER THAN A PERCENTAGE, because the question is "am I
               about to be locked out" and that is a shape, not a number. It
               turns when it is low: colour on this surface means look here. --%>
          <div class="mt-4 h-1.5 w-full overflow-hidden bg-neutral-400/15 dark:bg-neutral-300/15">
            <div
              class={[
                "h-full transition-[width] duration-500",
                (Identity.needs_renewal?(@passport) && "bg-primary-500 dark:bg-primary-600") ||
                  "bg-neutral-400 dark:bg-neutral-500"
              ]}
              style={"width: #{@passport.strength}%"}
            >
            </div>
          </div>
          <p
            :if={Identity.needs_renewal?(@passport)}
            class={[label_cls(), "pt-3 text-primary-600 dark:text-primary-500"]}
          >
            RUNNING LOW — ADD A FEW WORDS
          </p>
        </div>

        <p :if={@info} class={[label_cls(), "pt-6 text-primary-600 dark:text-primary-500"]}>
          {String.upcase(@info)}
        </p>

        <%!-- TOPPING UP IS THE WHOLE RECOVERY STORY, so it is one field and the
             return key. A button here would be a second thing to find for an
             act that is already one gesture. --%>
        <form id="pp-words" phx-submit="add_words" class="w-(--list-w) max-w-full pt-10">
          <p class={label_cls()}>ADD MORE WORDS</p>
          <.field name="words" value="" placeholder="SEPARATED BY SPACES" />
          <p class={hint_cls()}>Each one lets you in once, then it is spent.</p>
        </form>

        <%!-- ── APPEARING, OR NOT ────────────────────────────────────────
             THE ONE PREFERENCE IN AN APP OF FACTS. Everything else on this
             screen is something that IS true about you — your name, where you
             are, how many words you have left. This is the only thing you get
             to decide.

             IT IS HERE BECAUSE BEING AROUND IS AUTOMATIC. Opening the app is
             the whole gesture: there is no press, no confirmation, and by the
             time you would think to ask, you are already showing. A presence
             that switches itself on has to keep its way out somewhere you would
             think to look, and the room with your name at the top of it is that
             place.

             THE WORD IS THE CONTROL, in the same small tracked voice the rest
             of this room uses. A checkbox would be the first one in the app,
             and a toggle switch would be the first piece of somebody else's
             design language. It says what is true and pressing it makes the
             other thing true — which is the same shape as the population tag at
             the head of the list. --%>
        <div class="w-(--list-w) max-w-full pt-12">
          <p class={label_cls()}>BEING AROUND</p>
          <button
            type="button"
            phx-click="toggle_around"
            aria-pressed={to_string(not @person.around_hidden)}
            class={[
              "mt-4 w-full cursor-pointer px-4 py-3 text-(length:--sub-type) tracking-(--sub-track)",
              "transition-colors outline-none focus-visible:underline",
              (@person.around_hidden &&
                 "bg-neutral-400/10 text-neutral-500 hover:bg-neutral-400/20 dark:bg-neutral-300/10 dark:text-neutral-400") ||
                "bg-primary-600/15 text-primary-700 hover:bg-primary-600/25 dark:bg-primary-500/20 dark:text-primary-200"
            ]}
          >
            {(@person.around_hidden && "HIDDEN — NOBODY SEES YOU HERE") || "SHOWING WHEN YOU ARE HERE"}
          </button>
          <p class={hint_cls()}>
            Hidden means nobody sees that you are around, or what you are doing. Your letters
            still arrive.
          </p>
        </div>

        <.link
          href={~p"/passport/check-out"}
          method="delete"
          class="mt-12 cursor-pointer text-(length:--sub-type) tracking-(--sub-track) text-primary-600 transition-opacity hover:opacity-70 dark:text-primary-500"
        >
          CHECK OUT
        </.link>

        <.foot />
      </div>

      <%!-- WELCOME: one question, a door for each answer. --%>
      <div :if={@mode == :welcome} class="flex flex-col items-center gap-3">
        <.door type="button" tone={:primary} phx-click="choose" phx-value-mode="join">
          REQUEST PASSPORT
        </.door>
        <.door type="button" tone={:quiet} phx-click="choose" phx-value-mode="checkin">
          CHECK IN
        </.door>

        <.foot />
      </div>

      <%!-- ── JOIN ────────────────────────────────────────────────────────── --%>
      <div :if={@mode == :join}>
        <form id="pp-step" phx-submit="next" phx-change={change_for(@step)}>
          <div :if={@step == 1}>
            <p class={label_cls()}>NAME · 1 OF 5</p>
            <.field name="name" value={@name} placeholder="WHAT SHOULD WE CALL YOU" />
            <p class={hint_cls()}>
              {(@name_free == nil && "Two to ten letters or numbers.") ||
                (@name_free && "That name is free.") || "That name is taken."}
            </p>
          </div>

          <div :if={@step == 2}>
            <p class={label_cls()}>SECRET WORDS · 2 OF 5</p>
            <.field
              :for={{w, i} <- Enum.with_index(@words)}
              name={"word_#{i}"}
              value={w}
              placeholder={Enum.at(["FIRST WORD", "SECOND WORD", "AND A THIRD"], i)}
            />
            <p class={hint_cls()}>Each one is spent the first time it lets you in.</p>
          </div>

          <div :if={@step == 3}>
            <p class={label_cls()}>CODE · 3 OF 5</p>
            <.field name="code" value={@code} placeholder="1234" mode="numeric" />
            <p class={hint_cls()}>Four digits. This one never changes.</p>
          </div>

          <div :if={@step == 4}>
            <p class={label_cls()}>SAVE THESE · 4 OF 5</p>
            <p :for={w <- @words} class={word_cls()}>{w}</p>
            <p class={hint_cls()}>You will not be shown them again.</p>
          </div>

          <%!-- ── HOME, DETECTED ──────────────────────────────────────────
               A LIST OF EIGHTEEN COUNTRIES WAS THE WRONG QUESTION. It asked
               somebody to find their own country in a scroll, offered only the
               eighteen this app happened to know, and took their word for the
               answer — three problems for a fact the device already has.

               IT IS A GATE, NOT A WALL. The forward button sleeps until a place
               is known, and this is the only step where that happens, so the
               state has to be LOUD — a disabled button with no explanation is
               indistinguishable from a broken one. A refusal keeps a way back:
               the browser re-asks, and the hook is listening for the permission
               to flip, so changing your mind in the address bar unsticks this
               step without a reload. --%>
          <div :if={@step == 5}>
            <p class={label_cls()}>HOME · 5 OF 5</p>
            <p class={word_cls()}>{(@country && String.upcase(@country)) || "…"}</p>
            <p class={hint_cls()}>{geo_note(@geo)}</p>
            <button
              :if={@geo in [:denied, :unavailable]}
              type="button"
              phx-click="retry_location"
              class="cursor-pointer pt-3 text-(length:--sub-type) tracking-(--sub-track) text-primary-600 underline underline-offset-4 dark:text-primary-500"
            >
              TRY AGAIN
            </button>

            <%!-- THE LIST, AND IT ONLY EXISTS ONCE DETECTION HAS FAILED.
                 Detection is the whole point of this step: it is one fact the
                 device already holds, and asking somebody to find their own
                 country in a scroll of eighteen was a worse question three ways
                 over. But a browser that refuses, or a phone indoors that times
                 out, then leaves the LAST STEP OF SIGNING UP impossible to
                 finish — and a sign-up that cannot be finished is not a strict
                 policy, it is a broken app. So the list waits behind the
                 failure, invisible to everybody it worked for. --%>
            <div :if={@geo in [:denied, :unavailable]} class="pt-10">
              <p class={label_cls()}>OR SAY WHERE YOU ARE</p>
              <div class="flex flex-wrap justify-center gap-2 pt-4">
                <button
                  :for={c <- @countries}
                  type="button"
                  phx-click="country"
                  phx-value-country={c}
                  class={[
                    "cursor-pointer px-4 py-3 text-(length:--sub-type) tracking-(--sub-track) transition-colors",
                    (@country == c &&
                       "bg-primary-600/15 text-primary-600 dark:bg-primary-500/20 dark:text-primary-500") ||
                      "bg-neutral-400/10 text-neutral-500 hover:bg-neutral-400/20 dark:bg-neutral-300/10 dark:text-neutral-400"
                  ]}
                >
                  {String.upcase(c)}
                </button>
              </div>
            </div>
          </div>
        </form>

        <%!-- Mounted inside :join only, so nobody is asked for their location
             by a room they opened to look at their own word bank. --%>
        <div id="geo" phx-hook="Geolocation" class="hidden"></div>

        <.foot
          form="pp-step"
          back
          icon={(@step == 5 && :check) || :next}
          disabled={@step == 5 and is_nil(@country)}
        />
      </div>

      <%!-- ── CHECK IN ────────────────────────────────────────────────────── --%>
      <div :if={@mode == :checkin}>
        <form :if={@step == 1} id="pp-step" phx-submit="credentials">
          <p class={label_cls()}>CHECK IN · 1 OF 2</p>
          <.field name="name" value="" placeholder="YOUR NAME" />
          <.field name="word" value="" placeholder="ONE SECRET WORD" />
        </form>

        <form :if={@step == 2} id="pp-step" phx-submit="verify">
          <p class={label_cls()}>CODE · 2 OF 2</p>
          <.field name="code" value="" placeholder="1234" mode="numeric" />
        </form>

        <.foot form="pp-step" back icon={(@step == 2 && :check) || :next} />
      </div>
    </div>
    """
  end

  # ONE VOICE FOR EACH KIND OF LINE, as the reference had it — functions rather
  # than assigns, because they depend on nothing and a template that has to be
  # handed its own styles has stopped being a template.
  #
  # The step label is the smallest tracked type on the surface; the hint under a
  # field is a plain sentence in sentence case, because it is talking to you and
  # not labelling anything.
  # HEADINGS AND HINTS ARE WORDS, so they step in to --list-pad with the mark
  # and the room title. Fields, doors and the foot are CONTENT and begin at the
  # rail — the same two edges the page behind this panel has always had.
  defp label_cls,
    do:
      "px-(--list-pad) text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500"

  # HINTS SPEAK IN CAPITALS TOO, and by CSS rather than by rewriting each one —
  # these are sentences, and a sentence written in capitals in the source is a
  # sentence nobody can read while editing it. The tracking comes with the
  # transform: caps at twelve pixels with normal spacing set solid, and a hint
  # is the one line here that is genuinely meant to be read rather than scanned.
  defp hint_cls,
    do:
      "px-(--list-pad) pt-3 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 uppercase dark:text-neutral-500"

  # A word being handed back to be written down is not a field and not a label —
  # it is the thing itself, so it gets the room's largest voice.
  defp word_cls,
    do: "pt-6 text-(length:--count-type) tracking-(--row-track) text-light-900 dark:text-dark-100"

  # Only the steps with a field to change ask to hear every keystroke.
  defp change_for(step) when step in [1, 2, 3], do: ~w(name words code) |> Enum.at(step - 1)
  defp change_for(_), do: nil

  # THE FOOT IS THE LAUNCHER'S, not this room's. It was written here first —
  # the reference's grouped pair, a quiet back beside a larger forward — and
  # then every other room needed the same row, plus the way OUT of the panel
  # standing in it. One component now, imported; see `Launcher.foot/1`.

  # ── THE FIELD ───────────────────────────────────────────────────────────────
  # THE PANEL'S QUIET VOICE, copied from the reference and left as found:
  # transparent, BORDERLESS, and large. It had a rule under it here for a while
  # on the reasoning that a field should not look like the filled boxes you
  # press — but a rule is chrome too, and the reference's answer is better. The
  # placeholder says where to write and the caret says you are writing; nothing
  # else is needed, and a column of underlines reads as a form to be processed
  # rather than a question being asked.
  #
  # Left, not centred. That is the one change.
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: nil
  attr :mode, :string, default: "text"

  defp field(assigns) do
    ~H"""
    <input
      type="text"
      name={@name}
      value={@value}
      placeholder={@placeholder}
      inputmode={@mode}
      autocomplete="off"
      autocapitalize="off"
      spellcheck="false"
      phx-debounce="200"
      class="w-full bg-transparent pt-6 text-(length:--field-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
    />
    """
  end
end
