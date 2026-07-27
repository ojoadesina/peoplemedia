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

  import PeoplemediaWeb.FabPanel, only: [door: 1]

  alias Peoplemedia.{Directory, Identity, People}
  alias PeoplemediaWeb.Plugs.PassportAuth

  @words 3

  @impl true
  def mount(_params, _session, socket) do
    {:ok, reset(socket), layout: false}
  end

  defp reset(socket) do
    assign(socket,
      # The same roll of places the list scrolls. There is one list of countries
      # in this app and this is it — a second one here would be a second truth.
      countries: Enum.map(Directory.countries(), & &1.name),
      mode: :welcome,
      step: 1,
      name: "",
      name_free: nil,
      words: List.duplicate("", @words),
      code: "",
      country: nil,
      # Check-in carries the passport and the word it matched between its two
      # steps — the word is not spent until the code lands.
      passport: nil,
      secret_id: nil,
      error: nil
    )
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

  def handle_event("next", _params, %{assigns: %{mode: :join, step: 2}} = socket) do
    words = Enum.map(socket.assigns.words, &String.trim/1)

    cond do
      Enum.any?(words, &(String.length(&1) < 3)) ->
        {:noreply, assign(socket, error: "Three words, three letters or more.")}

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

  def handle_event("country", %{"country" => country}, socket) do
    {:noreply, assign(socket, country: country, error: nil)}
  end

  # THE LAST STEP IS THE ONLY ONE THAT WRITES. Everything before it is held here
  # and nothing exists until the whole passport can be made at once — a person
  # row with no passport is a person nobody can be.
  def handle_event("next", _params, %{assigns: %{mode: :join, step: 5}} = socket) do
    %{name: name, words: words, code: code, country: country} = socket.assigns

    with {:ok, person} <- People.create_person(%{name: name, country: country}),
         {:ok, _passport} <- Identity.create_passport(person, name, words, code) do
      {:noreply, check_in(socket, person)}
    else
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
        {:noreply, socket |> reset() |> assign(mode: :checkin, error: locked_error(seconds))}

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

      <%!-- WELCOME: one question, a door for each answer. --%>
      <div :if={@mode == :welcome} class="flex flex-col gap-3">
        <.door type="button" tone={:primary} phx-click="choose" phx-value-mode="join">
          REQUEST PASSPORT
        </.door>
        <.door type="button" tone={:quiet} phx-click="choose" phx-value-mode="checkin">
          CHECK IN
        </.door>
      </div>

      <%!-- ── JOIN ────────────────────────────────────────────────────────── --%>
      <div :if={@mode == :join}>
        <form id="pp-step" phx-submit="next" phx-change={change_for(@step)}>
          <div :if={@step == 1}>
            <p class={label_cls()}>NAME · 1 OF 5</p>
            <.field name="name" value={@name} placeholder="what should we call you" />
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
              placeholder={Enum.at(["First word", "Second word", "And a third"], i)}
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

          <div :if={@step == 5}>
            <p class={label_cls()}>HOME · 5 OF 5</p>
            <div class="flex flex-wrap gap-2 pt-6">
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
            <p class={hint_cls()}>Country is as fine as this gets.</p>
          </div>
        </form>

        <.foot
          form="pp-step"
          icon={(@step == 5 && :check) || :next}
          disabled={@step == 5 and is_nil(@country)}
        />
      </div>

      <%!-- ── CHECK IN ────────────────────────────────────────────────────── --%>
      <div :if={@mode == :checkin}>
        <form :if={@step == 1} id="pp-step" phx-submit="credentials">
          <p class={label_cls()}>CHECK IN · 1 OF 2</p>
          <.field name="name" value="" placeholder="Your name" />
          <.field name="word" value="" placeholder="One secret word" />
        </form>

        <form :if={@step == 2} id="pp-step" phx-submit="verify">
          <p class={label_cls()}>CODE · 2 OF 2</p>
          <.field name="code" value="" placeholder="1234" mode="numeric" />
        </form>

        <.foot form="pp-step" icon={(@step == 2 && :check) || :next} />
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
  defp label_cls,
    do: "text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500"

  defp hint_cls,
    do: "pt-3 text-(length:--sub-type) text-neutral-400 dark:text-neutral-500"

  # A word being handed back to be written down is not a field and not a label —
  # it is the thing itself, so it gets the room's largest voice.
  defp word_cls,
    do: "pt-6 text-(length:--count-type) tracking-(--row-track) text-light-900 dark:text-dark-100"

  # Only the steps with a field to change ask to hear every keystroke.
  defp change_for(step) when step in [1, 2, 3], do: ~w(name words code) |> Enum.at(step - 1)
  defp change_for(_), do: nil

  # ── THE FOOT ────────────────────────────────────────────────────────────────
  # THE REFERENCE'S GROUPED PAIR, kept: a quiet back beside a larger forward,
  # and `form=` submits the step's form from OUTSIDE it — which is what lets one
  # foot serve every step without each step growing its own button row.
  #
  # SQUARE, not round, and left-aligned rather than centred. The forward is the
  # only solid terracotta thing in the room, and it grows a check on the last
  # step because finishing and continuing are not the same promise.
  attr :form, :string, required: true
  attr :icon, :atom, default: :next
  attr :disabled, :boolean, default: false

  defp foot(assigns) do
    ~H"""
    <div class="flex items-center gap-4 pt-10">
      <button
        type="button"
        phx-click="back"
        aria-label="Back"
        class="flex size-12 cursor-pointer items-center justify-center bg-neutral-400/10 text-neutral-500 transition-colors hover:bg-neutral-400/20 hover:text-neutral-600 dark:bg-neutral-300/10 dark:text-neutral-400 dark:hover:bg-neutral-300/20"
      >
        <.chevron dir="left" />
      </button>
      <button
        type="submit"
        form={@form}
        disabled={@disabled}
        aria-label={(@icon == :check && "Finish") || "Continue"}
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
    """
  end

  attr :dir, :string, required: true

  defp chevron(assigns) do
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
      class="w-full bg-transparent pt-6 text-(length:--count-type) tracking-(--row-track) text-light-900 outline-none dark:text-dark-100"
    />
    """
  end
end
