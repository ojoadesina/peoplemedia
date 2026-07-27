defmodule PeoplemediaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  Styling is hand-written Tailwind against the house palette in `app.css` —
  there is no component library underneath, so what you read here is what
  renders. Four rules keep the set coherent:

    * SURFACES come from two ramps, not one: `light-*` (warm, cream to cocoa)
      and `dark-*` (black and untinted greys). Every colour utility therefore
      ships with a `dark:` twin, and they run in OPPOSITE directions. Light's
      page is `light-50` and everything real on it is darker; dark's page is
      `dark-950` and everything real on it is lighter. Never pair them by
      number — `text-light-900 dark:text-dark-100` is a matched pair, and
      `dark:text-dark-900` on the dark page would be invisible.
    * `primary` (terracotta) means ATTENTION — the pressed button, the invalid
      field, the error flash. The palette carries no separate red, and it does
      not need one.
    * `secondary` (sage) means AFFIRMATION — the info flash, the presence dot,
      and the flow arrow that says a letter of yours has been read. It is the
      RECEIPT colour: something completed, with nothing being asked of you.
      Terracotta asks, sage reports. Spend it sparingly, and never on a state
      the reader is meant to act on.
    * SIZES come from the custom type scale, which is tighter than Tailwind's
      stock ramp — `text-md` here is 0.875rem, and `text-xl` is 1rem, not
      1.25rem. Never assume a stock size means what it usually means.

  Useful references:

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # Every input type shares one shell, so a text field and a select can never
  # drift apart on border, radius, focus ring or disabled treatment.
  #
  # These are FUNCTIONS, not module attributes, because inside ~H the `@name`
  # form always means `assigns.name` — a module attribute referenced that way in
  # a template silently becomes a missing-assign crash at render time.
  defp input_base do
    "w-full rounded-md border bg-light-50 px-3 py-2 text-md text-light-900 " <>
      "placeholder:text-light-400 transition-colors outline-none " <>
      "focus-visible:ring-2 focus-visible:ring-primary-500/40 " <>
      "disabled:cursor-not-allowed disabled:opacity-50 " <>
      "dark:bg-dark-900 dark:text-dark-100 dark:placeholder:text-dark-500"
  end

  defp input_ok do
    "border-light-200 focus-visible:border-primary-500 dark:border-dark-800"
  end

  defp input_bad do
    "border-primary-600 focus-visible:border-primary-600 dark:border-primary-500"
  end

  # The label above every field. One definition so a select and a text input can
  # never disagree about weight or spacing.
  defp field_label do
    "mb-1 block text-sm font-medium text-light-700 dark:text-dark-300"
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 w-80 cursor-pointer sm:w-96"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 rounded-lg border p-4 text-md shadow-lg text-wrap",
        @kind == :info &&
          "border-secondary-200 bg-secondary-50 text-secondary-900 dark:border-secondary-800 dark:bg-secondary-950 dark:text-secondary-100",
        @kind == :error &&
          "border-primary-200 bg-primary-50 text-primary-900 dark:border-primary-800 dark:bg-primary-950 dark:text-primary-100"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div class="flex-1">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <button type="button" class="group cursor-pointer self-start" aria-label="close">
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    base =
      "inline-flex cursor-pointer items-center justify-center gap-2 rounded-md px-4 py-2 " <>
        "text-md font-semibold transition-colors outline-none " <>
        "focus-visible:ring-2 focus-visible:ring-primary-500/40 focus-visible:ring-offset-2 " <>
        "focus-visible:ring-offset-light-50 dark:focus-visible:ring-offset-dark-950 " <>
        "disabled:pointer-events-none disabled:opacity-50"

    # Solid carries the page's one primary action. Soft is the same colour at low
    # ink, so a row of secondary actions reads as a group rather than as noise.
    variants = %{
      "primary" =>
        "bg-primary-600 text-primary-50 hover:bg-primary-700 dark:bg-primary-500 dark:hover:bg-primary-600",
      nil =>
        "bg-primary-100 text-primary-800 hover:bg-primary-150 dark:bg-primary-950 dark:text-primary-200 dark:hover:bg-primary-900"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        [base, Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-2">
      <label class="flex items-center gap-2 text-md text-light-900 dark:text-dark-100">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class ||
              "size-4 shrink-0 cursor-pointer rounded border-light-300 accent-primary-600 " <>
                "outline-none focus-visible:ring-2 focus-visible:ring-primary-500/40 " <>
                "dark:border-dark-700 dark:accent-primary-500"
          }
          {@rest}
        />{@label}
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label>
        <span :if={@label} class={field_label()}>{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[
            @class || [input_base(), "cursor-pointer"],
            @errors == [] && !@class && input_ok(),
            @errors != [] && (@error_class || input_bad())
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-2">
      <label>
        <span :if={@label} class={field_label()}>{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || [input_base(), "min-h-24"],
            @errors == [] && !@class && input_ok(),
            @errors != [] && (@error_class || input_bad())
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-2">
      <label>
        <span :if={@label} class={field_label()}>{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || input_base(),
            @errors == [] && !@class && input_ok(),
            @errors != [] && (@error_class || input_bad())
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-2 text-sm text-primary-700 dark:text-primary-400">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-3xl font-semibold leading-8 text-light-900 dark:text-dark-100">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-md text-light-600 dark:text-dark-400">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <%!-- The wrapper is what keeps a wide table from pushing the PAGE sideways:
         it scrolls inside its own box instead. --%>
    <div class="w-full overflow-x-auto">
      <table class="w-full border-collapse text-left text-md">
        <thead class="border-b border-light-200 dark:border-dark-800">
          <tr>
            <th
              :for={col <- @col}
              class="p-3 text-sm font-semibold tracking-wide text-light-600 uppercase dark:text-dark-400"
            >
              {col[:label]}
            </th>
            <th :if={@action != []} class="p-3">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="text-light-900 dark:text-dark-100"
        >
          <%!-- Zebra striping by hand. nth-child on the ROW rather than a class on
               each cell, so a stream insert cannot land on the wrong colour. --%>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="border-b border-light-150 odd:bg-light-100/50 hover:bg-primary-50 dark:border-dark-800 dark:odd:bg-dark-900/40 dark:hover:bg-primary-950/40"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["p-3", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 p-3 font-semibold">
              <div class="flex gap-4">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="divide-y divide-light-200 dark:divide-dark-800">
      <li :for={item <- @item} class="flex flex-col gap-1 py-4">
        <div class="text-sm font-semibold tracking-wide text-light-600 uppercase dark:text-dark-400">
          {item.title}
        </div>
        <div class="text-md text-light-900 dark:text-dark-100">{render_slot(item)}</div>
      </li>
    </ul>
    """
  end

  @doc """
  THE SCREEN under the band, shared by both presence surfaces so they cannot
  drift apart.

  Capture READIES it; it does not play until it is tapped. A face shows its
  first frame with a play mark over it; a voice shows an empty bar. Nothing
  moves and nothing sounds while you are only scrolling past — that is the whole
  point of it: the box captures what settles in it, but settling is what
  browsing looks like too, and the interface cannot tell "I am scanning past
  this" from "I want this one." So it stops guessing. One tap on the screen
  plays the presence, with sound, and the play mark clears.

  The slot holds its full height whatever it carries, and stands even for text
  where it holds nothing — reserved so scrolling never re-lays the page out, and
  present with a stable id so a screenless presence does not delete the element
  and reset the list's scroll.
  """
  attr :id, :string, required: true
  attr :presence, :map, default: nil

  def presence_screen(assigns) do
    ~H"""
    <div id="screen-slot" class="h-54 w-[32rem]">
      <div
        :if={@presence && @presence.kind != "text"}
        id={@id}
        phx-hook="Screen"
        phx-update="ignore"
        data-media={@presence.media}
        data-kind={@presence.kind}
        class="screen relative flex h-full w-[32rem] cursor-pointer flex-col justify-center"
      >
        <%!-- A FACE, readied on its first frame, the play mark over the picture
             and the count bottom left where the recorder kept it. --%>
        <div :if={@presence.kind == "face"} class="relative h-full w-full overflow-hidden bg-black">
          <video
            class="screen-video absolute inset-0 h-full w-full object-cover"
            playsinline
            preload="metadata"
          >
          </video>
          <span class="screen-play pointer-events-none absolute inset-0 flex items-center justify-center">
            <.icon name="hero-play-solid" class="h-12 w-12 text-light-50/85" />
          </span>
          <div class="absolute bottom-4 left-8">
            <span class="screen-time text-sm text-dark-400">0:00</span>
          </div>
        </div>

        <%!-- A VOICE: a hairline, the play mark beside its count. No picture to
             lay a mark over, so it sits with the count under the bar. --%>
        <div :if={@presence.kind == "voice"} class="relative w-full">
          <div class="h-[3px] w-full overflow-hidden bg-secondary-500/30">
            <div class="screen-fill h-full bg-secondary-500" style="width: var(--played, 0%)"></div>
          </div>
          <div class="absolute top-3 left-0 flex items-center gap-2">
            <span class="screen-play">
              <.icon name="hero-play-solid" class="h-3.5 w-3.5 text-secondary-500" />
            </span>
            <span class="screen-time text-sm text-light-500 dark:text-dark-500">0:00</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  THE KIND MARK — a small symbol that says, before the name, what a letter
  arrived as.

  Three marks, all cut from one rectangle:

    FACE  is the two EYES — two rectangles side by side, "- -".
    VOICE is the one MOUTH — a single rectangle, "--", as wide as the two eyes
          span END TO END: from the left edge of the left eye to the right edge
          of the right eye, gap included, so the mouth covers exactly the width
          the two eyes do.
    TEXT  is that same mouth TURNED HALFWAY OVER — the identical rectangle, the
          identical width, rotated 45 degrees about its own centre.

  A face has eyes; a voice has a mouth. Every bar shares one height, sharp
  corners, no curve anywhere.

  ## WHY TEXT IS THE MOUTH STRUCK THROUGH

  Because it is the only one of the three defined by ABSENCE, and a slash is
  what a surface says "not this" with. A text letter is a letter with no face in
  it and no voice in it — the plain case, words and nothing else — so drawing it
  a mark of its own (a page, a line of dashes, a quote) would have made it a
  fourth kind of thing standing beside the other two. It is not beside them, it
  is what is left when both are taken away, and one bar tipped off the level
  says exactly that: the mouth is there, and it is shut.

  It rises left to right rather than falling, which is the one choice with no
  argument behind it beyond this: on a surface that reads left to right, a
  rising stroke is a MARK, and a falling one is the cross people put through a
  mistake. Nothing is wrong with a text letter.

  ## THE EMPTY SLOT

  `kind={nil}` draws nothing and still takes the width. Anything that has to
  line up with a row carries one: a stranger's row (a letter is written to a
  SCOPE, not to a person, so they have none), the picked header, the lens at
  the head of the list. Without it every name in those places starts a mark's
  width left of every name in the list.

  IT HAS WIDTH BUT NO HEIGHT, and that is load-bearing rather than tidy. An
  empty box with a HEIGHT has no baseline of its own, so in a
  `items-baseline` flex row — which the picked header is, because the label and
  the quiet name beside it must sit on one line — the box falls back to
  aligning its BOTTOM EDGE to the text baseline. That drags the header's name
  most of a mark's height down the box, and the pick, whose whole trick is that
  the label does not appear to move, visibly jumps. With no height it cannot
  affect the line box at all, which is exactly what a spacer should do.

  BOTH VARIANTS TAKE THEIR WIDTH FROM `em`, so the column tracks the type. Any
  caller therefore has to be setting the row's font-size on itself or on an
  ancestor, or its mark will be sized against the page default and stand in a
  narrower column than the rows do.

  ## QUIET IS FOR THE ONES WITH NOTHING TO SAY

  `lit` is the whole of it. A mark on a row with an unopened letter is drawn at
  FULL strength in terracotta, because that is the one thing on this surface
  that is asking for you and holding it back would be holding back the only
  signal the list has. Every other mark — a letter you have read, anything in
  the panel — is grey and soft.

  Dimming both was the mistake in between, and it is worth writing down why it
  was tempting: nineteen filled rectangles down the left DO read as a second
  list, louder than the names they annotate, so the instinct to turn the whole
  column down is right. What it misses is that the column is not uniform. Six
  of those nineteen are asking for something and thirteen are not, and turning
  all nineteen down flattens exactly the difference the marks exist to draw.
  The size came down for everyone (1.7em to 1.4em); the STRENGTH came down only
  for the ones with nothing to say.

  THE BAND GIVES IT BACK to the rest. `.is-focused` returns any mark to full
  strength, so the row you are on states its kind plainly while the ones you
  are not stay out of the way.
  """
  attr :kind, :any, required: true
  attr :lit, :boolean, default: false
  attr :class, :any, default: nil

  def letter_glyph(assigns) do
    ~H"""
    <span
      class={[
        "letter-glyph shrink-0 w-[1.4em]",
        @kind && "flex h-[1.4em]",
        @lit && "is-lit",
        @class
      ]}
      aria-hidden="true"
    >
      <svg :if={@kind == "face"} viewBox="0 0 24 24" class="h-full w-full" fill="currentColor">
        <rect x="4" y="9" width="6" height="6" />
        <rect x="14" y="9" width="6" height="6" />
      </svg>
      <svg :if={@kind == "voice"} viewBox="0 0 24 24" class="h-full w-full" fill="currentColor">
        <rect x="4" y="9" width="16" height="6" />
      </svg>
      <%!-- The voice bar and nothing else, turned about the box's centre. Not a
           second drawing: same x, same y, same 16x6, so the two kinds cannot
           drift apart when either is retuned. --%>
      <svg :if={@kind == "text"} viewBox="0 0 24 24" class="h-full w-full" fill="currentColor">
        <rect x="4" y="9" width="16" height="6" transform="rotate(-45 12 12)" />
      </svg>
    </span>
    """
  end

  @doc """
  THE FLOW — which way the last letters went, and whether they landed.

  Two arrows on the right of a row, out on the left and in on the right, the
  same order a page is read in: what you sent, then what came back.

  Each answers a DIFFERENT question, which is why they are two marks and not one
  toggle:

    ↑ OUT is shown only while the newest letter in the thread is YOURS. Lit once
      they have opened it, faded while they have not. It goes away the moment
      they write back — an arrow still up for a letter you sent last week would
      read as a reply still in flight, when the conversation has long since
      moved past it.

    ↓ IN is shown as soon as they have ever written. Lit while their newest
      letter is unopened, faded once you have read it.

  ## TWO LIT COLOURS, AND THEY ARE NOT THE SAME COLOUR

  Terracotta is this surface's word for LOOK HERE, and it is spent on the one
  thing a row can be asking of you: an unopened letter. So ↓ lights terracotta,
  the same colour the kind mark takes for the same reason.

  ↑ lit is not a request, it is a RECEIPT — they opened what you sent, and there
  is nothing for you to do about it. Spending terracotta on that would put a
  finished thing and a waiting thing in the same voice, and a list where
  everything is urgent has no way left to say that something is. So it takes
  sage, the theme's other hue, which appears nowhere else on this surface and
  means only this. Warm asks, cool reports.

  Faded is the resting state of both and is deliberately very quiet: on a list
  of nineteen rows these marks are almost always saying nothing has changed, and
  a column of legible arrows down the right-hand side would be the loudest thing
  on a page whose subject is the names.
  """
  attr :letter, :map, required: true
  attr :class, :any, default: nil

  def letter_flow(assigns) do
    ~H"""
    <%!-- ON THE NAME'S LINE, not centred in the row. It used to stretch the
         row's full height, which put the pair below both lines of text and made
         them read as a third thing floating at the right rather than as the
         other half of what the kind mark on the left is saying. The two marks
         are one pair; a pair sits on one line. --%>
    <span class={["letter-flow flex shrink-0 items-center gap-2", @class]}>
      <.flow_arrow
        :if={@letter.outgoing}
        dir="up"
        lit={@letter.outgoing == :read}
        label={(@letter.outgoing == :read && "Your letter has been read") || "Your letter is unread"}
      />
      <.flow_arrow
        :if={@letter.incoming}
        dir="down"
        lit={@letter.incoming == :unread}
        label={(@letter.incoming == :unread && "Unread letter from them") || "Their letter, read"}
      />
    </span>
    """
  end

  # A STEM AND A HEAD, drawn open, both 15 units long with the head spanning 13
  # across — a 90-degree point, which is the widest an arrowhead reads as sharp.
  #
  # MITRED JOINS AND BUTT CAPS. The join is mitred because every corner on this
  # surface is square and a rounded arrowhead would be the one soft thing on it.
  # The caps are butt for a reason that is geometry rather than taste: the stem
  # ENDS ON THE HEAD'S APEX, so a square cap would extend it half a stroke past
  # the point and put a spike out of the top of the arrow. Butt cuts it flat
  # exactly where the head takes over, and the head's own miter covers the seam.
  attr :dir, :string, required: true
  attr :lit, :boolean, required: true
  attr :label, :string, required: true

  defp flow_arrow(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      class={
        [
          # SIZED IN em, NOT PIXELS, so the pair tracks the row's type. At a fixed
          # 16px they were right on a phone and visibly undersized on a wide
          # screen, where the row grows and they did not — the marks drifted from
          # "quiet" to "hard to find". 1.05em holds them just over the cap height
          # of the name beside them and still under the kind mark's 1.4em,
          # which is the order of loudness these three are meant to be read in.
          #
          # QUIET IS THE OPACITY'S JOB, not the size's. A small faint mark is
          # merely illegible; a normally-sized faint one is legible when you look
          # for it and invisible when you do not, which is the whole brief.
          "size-[1.05em] transition-colors duration-200",
          @lit && @dir == "down" && "text-primary-600 dark:text-primary-500",
          @lit && @dir == "up" && "text-secondary-600 dark:text-secondary-400",
          !@lit && "text-neutral-400/40 dark:text-neutral-500/55"
        ]
      }
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="butt"
      stroke-linejoin="miter"
      role="img"
      aria-label={@label}
    >
      <path :if={@dir == "up"} d="M12 20V5" />
      <path :if={@dir == "up"} d="M5.5 11.5 12 5l6.5 6.5" />
      <path :if={@dir == "down"} d="M12 4v15" />
      <path :if={@dir == "down"} d="M5.5 12.5 12 19l6.5-6.5" />
    </svg>
    """
  end

  @doc """
  Renders a LEFT PRESENCE — one someone recorded and left behind.

  Two variants of one object, and which you get depends on where it is.

  ## `:card` — waiting in the list

  The recorder's cover, and only that: who left it, when, how long, and the note
  they attached. It does not swipe. There is nothing behind it to reach, and a
  scroller that scrolls nowhere is a promise the interface cannot keep.

  ## `:open` — captured by the box

  The cover is GONE, not slid aside, and the media plays the moment it arrives.
  Asking for a swipe here was friction dressed as an interaction: the box exists
  to show more than the row could, so making you work for it is the box failing
  at its one job. Worse, it hid the media twice — once in the list and again
  behind a card — when the whole point of scrolling something into the box is
  that you want it.

  So `:open` keeps two layers. The first plays: a voice fills it with the sage
  pane and its status line, a face fills it with the picture. The second is
  deliberately empty, waiting for whatever earns it.

  ## Examples

      <.presence presence={@presence} by="SARAH" id="p-1" />
      <.presence presence={@presence} by="SARAH" id="p-1" variant={:open} />
  """
  attr :id, :string, required: true
  attr :presence, :map, required: true
  attr :by, :string, required: true
  attr :variant, :atom, values: [:card, :open], default: :card

  def presence(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook={@variant == :open && "Presence"}
      data-media={@presence.media}
      data-kind={@presence.kind}
      class={[
        "presence relative h-54 w-[32rem] shrink-0",
        !@presence.heard && "is-unheard"
      ]}
    >
      <%= if @variant == :open do %>
        <%!-- THE SCREEN, and nothing over it. --%>
        <div class="presence-entry absolute inset-0 w-full overflow-hidden">
          <div class="relative h-full w-full bg-black">
            <video
              class="presence-video absolute inset-0 hidden h-full w-full object-cover"
              playsinline
              preload="none"
            >
            </video>

            <div class="absolute bottom-4 left-8 flex flex-col space-y-4">
              <p class="presence-status text-sm tracking-[0.14em] text-sky-400"></p>
              <span class="presence-elapsed text-sm tracking-[0.14em] text-neutral-400">0:00</span>
            </div>
          </div>
        </div>

        <div class="presence-layer no-scrollbar relative flex h-full snap-x snap-mandatory overflow-x-auto">
          <%!-- LAYER ONE PLAYS. A voice has nothing to look at, so it gets the
               sage pane over the screen and the status line carries the message;
               a face has something to look at, so this layer stays out of its
               way entirely. --%>
          <div class="presence-stage h-full w-full shrink-0 snap-start">
            <div
              :if={@presence.kind != "face"}
              class="flex h-full w-full items-end bg-secondary-500/60 px-8 pb-16"
            >
              <%!-- A TEXT PRESENCE HAS NOTHING TO PLAY, so the stage shows the
                   one thing it does have. Without this the box opened onto a
                   black rectangle and a clock that never moved — a dead end
                   reached by scrolling towards it. --%>
              <p
                :if={@presence.kind == "text"}
                class="presence-note line-clamp-4 text-sm leading-6 tracking-[0.14em] text-light-50"
              >
                {@presence.note}
              </p>
            </div>
          </div>

          <%!-- LAYER TWO IS EMPTY ON PURPOSE, held for whatever earns it. It is
               still 95% wide, so the fact that there IS somewhere to go stays
               visible without announcing what. --%>
          <div class="presence-reserved w-[95%] shrink-0 snap-end"></div>
        </div>
      <% else %>
        <%!-- THE COVER, at rest. No arrow: nothing behind it to reach. --%>
        <div class="presence-cover relative h-full w-full bg-primary-100 dark:bg-primary-950">
          <div class="relative flex h-full w-full flex-col space-y-4 px-4 py-4">
            <div class="flex items-start justify-between">
              <button
                type="button"
                class="presence-plus cursor-pointer text-primary-500 transition hover:text-primary-600"
                aria-label="Unassigned"
              >
                <.icon name="hero-plus" class="h-5 w-5" />
              </button>

              <div class="text-right">
                <div class="flex items-center justify-end gap-1 text-sm tracking-[0.14em]">
                  <span class="text-primary-600 dark:text-primary-400">{@by},</span>
                  <span class="text-neutral-400">{@presence.when}</span>
                </div>
                <span :if={@presence.len} class="text-sm tracking-[0.14em] text-neutral-400">
                  {@presence.len}
                </span>
              </div>
            </div>

            <div class="flex-1"></div>

            <p class={[
              "presence-note text-sm leading-5 tracking-[0.14em] text-primary-700 dark:text-primary-300",
              @presence.kind == "text" && "line-clamp-4"
            ]}>
              {@presence.note}
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the mark: a face, in the app's own handwriting.

  It is the whole argument of the product in one shape — people are the primary
  focus — so it is a FACE rather than a monogram or a glyph of a network. What
  changed is HOW it draws one. This surface already had a face: `letter_glyph`
  says a face is TWO RECTANGLES and a voice is ONE, and those proportions are
  deliberate (the mouth is exactly as wide as the eyes' span). The mark used to
  answer the same question differently — a circle with two round eyes — so the
  app drew a face two contradictory ways, and the round one was the odd shape on
  a surface that is square everywhere else and argues, in its own comments, that
  rounding a screen turns it into a widget.

  So the mark is the glyph at mark scale: the same two squares, the same gap,
  cropped to their own bounds so they fill the box. One way to draw a face.

  ## THE EYES ARE SHUT

  And that is the whole of what changed. The box is the same 16x6, the eyes are
  the same 6 wide at the same two ends of it — they are simply DRAWN CLOSED, one
  unit deep, on the line they would close onto anyway. Open, they are the two
  squares this file has always described; the cycle in app.css is what opens
  them, and scaleY(6) is exactly the ratio between the two states, so "open" is
  not a second drawing but the same rect at full height.

  SHUT EYES ARE NOT ABSENT EYES, and it is worth writing down which reading this
  is, because the shape does not fix its own meaning. Closed eyes are what a
  face does laughing, wincing, listening hard, or holding something in — the
  vocabulary people actually use for them (`^_^`) is delight far more often than
  sleep. Add a tear and the same two lines are crying; add a curve and they are
  loving. What decides it is the company they keep, and the company here is a
  wink: nothing winks but a face, and nothing winks while absent.

  DRAWN CLOSED, NOT HELD CLOSED, and the distinction is what makes this a rest
  state rather than an animation trick. Anything that renders the mark without
  running CSS — a favicon, a thumbnailer, a print sheet, `animated={false}` —
  gets the shut eyes, because the shut eyes are the artwork. Holding a square
  down with a transform would have made stillness a failure mode.

  `animated` runs the cycle, after drawing the closed pair on: each eye sweeps
  out from its own centre on arrival, the second a beat behind the first, so the
  entrance reads as the eyes being drawn rather than as two lines appearing.
  Pass `animated={false}` where stillness matters.

  ## Examples

      <.head />
      <.head class="h-7 text-primary-600" animated={false} />
  """
  # :any rather than :string so a caller can pass nil and mean it. THE APP RULE
  # does: it sets the mark's height itself, because the rule's own weight and
  # gaps are derived from that height, and it sets the colour on the wrapper so
  # the eyes and the line they sit in cannot end up different shades. The default
  # below carries a fixed primary-500 with no dark twin, which is exactly what
  # that caller must be able to opt out of. Same convention `button/1` uses.
  attr :class, :any, default: "h-7 text-primary-500"
  attr :animated, :boolean, default: true
  attr :rest, :global

  def head(assigns) do
    ~H"""
    <svg
      class={["head", @animated && "is-animated", @class]}
      viewBox="0 0 16 6"
      fill="currentColor"
      aria-hidden="true"
      {@rest}
    >
      <%!-- One unit deep, centred on the line a 6-square would close onto, so
             scaleY(6) reopens each eye into exactly the square it came from. --%>
      <rect class="head-eye" x="0" y="2.5" width="6" height="1" />
      <rect class="head-eye" x="10" y="2.5" width="6" height="1" />
    </svg>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(PeoplemediaWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(PeoplemediaWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
