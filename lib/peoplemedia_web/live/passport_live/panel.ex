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
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <p
        :if={@error}
        class="pb-4 text-(length:--sub-type) tracking-(--sub-track) text-primary-600 dark:text-primary-500"
      >
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
      <form :if={@mode == :join} phx-submit="next" phx-change={change_for(@step)}>
        <.step_label :if={@step == 1} n={1} of={5}>NAME</.step_label>
        <div :if={@step == 1}>
          <.field name="name" value={@name} placeholder="what should we call you" />
          <p class="mt-3 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            {(@name_free == nil && "TWO TO TEN LETTERS OR NUMBERS") ||
              (@name_free && "THAT NAME IS FREE") || "THAT NAME IS TAKEN"}
          </p>
        </div>

        <.step_label :if={@step == 2} n={2} of={5}>THREE WORDS</.step_label>
        <div :if={@step == 2} class="flex flex-col gap-4">
          <.field
            :for={{w, i} <- Enum.with_index(@words)}
            name={"word_#{i}"}
            value={w}
            placeholder={Enum.at(~w(first second third), i)}
          />
          <p class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            EACH ONE IS SPENT THE FIRST TIME IT LETS YOU IN
          </p>
        </div>

        <.step_label :if={@step == 3} n={3} of={5}>CODE</.step_label>
        <div :if={@step == 3}>
          <.field name="code" value={@code} placeholder="1234" mode="numeric" />
          <p class="mt-3 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            FOUR DIGITS. THIS ONE DOES NOT CHANGE
          </p>
        </div>

        <.step_label :if={@step == 4} n={4} of={5}>WRITE THESE DOWN</.step_label>
        <div :if={@step == 4} class="flex flex-col gap-3">
          <p
            :for={w <- @words}
            class="bg-neutral-400/10 px-5 py-4 text-(length:--row-type) tracking-(--row-track) text-light-900 dark:bg-neutral-300/10 dark:text-dark-100"
          >
            {String.upcase(w)}
          </p>
          <p class="text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
            YOU WILL NOT BE SHOWN THEM AGAIN
          </p>
        </div>

        <.step_label :if={@step == 5} n={5} of={5}>WHERE IN THE WORLD</.step_label>
        <div :if={@step == 5} class="flex flex-wrap gap-2">
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

        <div class="mt-8 flex flex-col gap-3">
          <.door type="submit" tone={:primary} disabled={@step == 5 and is_nil(@country)}>
            {(@step == 5 && "MAKE IT") || "NEXT"}
          </.door>
          <.door type="button" tone={:quiet} phx-click="back">BACK</.door>
        </div>
      </form>

      <%!-- ── CHECK IN ────────────────────────────────────────────────────── --%>
      <form :if={@mode == :checkin and @step == 1} phx-submit="credentials">
        <.step_label n={1} of={2}>NAME AND A WORD</.step_label>
        <div class="flex flex-col gap-4">
          <.field name="name" value="" placeholder="your name" />
          <.field name="word" value="" placeholder="one of your words" />
        </div>
        <div class="mt-8 flex flex-col gap-3">
          <.door type="submit" tone={:primary}>NEXT</.door>
          <.door type="button" tone={:quiet} phx-click="back">BACK</.door>
        </div>
      </form>

      <form :if={@mode == :checkin and @step == 2} phx-submit="verify">
        <.step_label n={2} of={2}>CODE</.step_label>
        <.field name="code" value="" placeholder="1234" mode="numeric" />
        <div class="mt-8 flex flex-col gap-3">
          <.door type="submit" tone={:primary}>CHECK IN</.door>
          <.door type="button" tone={:quiet} phx-click="back">BACK</.door>
        </div>
      </form>
    </div>
    """
  end

  # Only the steps that need to hear every keystroke ask for one. Steps 4 and 5
  # have no field to change.
  defp change_for(step) when step in [1, 2, 3], do: ~w(name words code) |> Enum.at(step - 1)
  defp change_for(_), do: nil

  attr :n, :integer, required: true
  attr :of, :integer, required: true
  slot :inner_block, required: true

  defp step_label(assigns) do
    ~H"""
    <p class="pb-6 text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
      {render_slot(@inner_block)} · {@n} OF {@of}
    </p>
    """
  end

  # AN INPUT ON THIS SURFACE IS A LINE, not a box. Everything filled here is a
  # control you press; a field is somewhere you write, and giving it the same
  # wash would make the page look like it had two kinds of button. The rule
  # under it is the only chrome, and it takes the terracotta on focus because
  # that is this surface's word for "here".
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
      class={[
        "w-full border-0 border-b-2 border-neutral-400/30 bg-transparent px-0 pb-2",
        "text-(length:--row-type) tracking-(--row-track) text-light-900 dark:text-dark-100",
        "placeholder:text-neutral-400/50 dark:placeholder:text-neutral-500/50",
        "transition-colors outline-none focus:border-primary-600 dark:focus:border-primary-500",
        "dark:border-neutral-300/20"
      ]}
    />
    """
  end
end
