defmodule PeoplemediaWeb.LogoLive do
  @moduledoc """
  A CONTACT SHEET, not a feature. The two candidate marks at the sizes they will
  actually be used at, on both surfaces, so they can be judged before either is
  wired into anything.

  THE ARTWORK IS NEVER REPEATED HERE — but "the artwork" is not the same kind of
  thing for all of them, so it is shown two ways.

  The MARKS are files. They are `<img>`s of priv/static/logo, so what you are
  looking at is the deliverable itself rather than a HEEx copy free to drift out
  of step with it, and each renders in its own isolated context — the blink and
  the wink run off the artwork's own stylesheet exactly as they will wherever
  the file is dropped.

  The BAR is not a file. It is a CSS composition whose tail has no length of its
  own — it reaches whatever page it is put on — so a fixed-width SVG of it would
  be an approximation of the deliverable rather than the deliverable. It is
  therefore rendered with the same `.app-rule` and the same `head/1` the header
  itself uses, with only `--rule-ink` varied between the two variants, which is
  precisely the decision being compared. (priv/static/logo/logo-4.svg carries
  the same geometry at a fixed width, for anywhere a file is needed.)

  Delete this module and its route the day one of them is chosen.
  """
  use PeoplemediaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Logo")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-light-50 px-6 py-16 font-mono text-light-950 dark:bg-dark-950 dark:text-dark-50">
      <main class="mx-auto max-w-6xl">
        <h1 class="text-xl tracking-[0.15em]">KUISK · THE MARK AND THE NAME</h1>
        <p class="mt-3 mb-16 text-sm tracking-[0.14em] text-neutral-400">
          ONE MODULE (16), ONE STROKE (16), A HALF MODULE (8) BETWEEN LETTERS, SQUARE CORNERS, ONE INK
        </p>

        <section class="mb-20">
          <h2 class="text-sm tracking-[0.16em] text-primary-600 dark:text-primary-500">
            THE SHUT STATE — A STUDY
          </h2>
          <p class="mt-2 mb-8 max-w-3xl text-sm leading-7 tracking-[0.14em] text-neutral-400">
            Held still, because the question is about the resting shape and a moving one answers it
            differently every second. ONE STRAIGHT BAR HAS ONE SLOPE, so a tilted eye can only point
            its inner end up or down — and those are the two faces below: worried, and angry. The
            happy closed eye everyone actually draws is a caret, and a caret is an arch, which needs
            either a curve this surface does not own or three stepped segments per eye — and that
            would cost the mark the one relationship it is built on, that an eye is a single rect at
            two heights. The last one leaves the shape alone and only adds weight.
          </p>
          <div class="grid gap-6 sm:grid-cols-2">
            <.panel :for={surface <- [:light, :dark]} surface={surface}>
              <div :for={{label, cls} <- shut_studies()} class="flex flex-col items-center gap-4">
                <.head
                  animated={false}
                  class={[
                    "h-16",
                    cls,
                    surface == :light && "text-primary-600",
                    surface == :dark && "text-primary-500"
                  ]}
                />
                <span class="text-center text-xs tracking-[0.14em] text-neutral-400">{label}</span>
              </div>
            </.panel>
          </div>
        </section>

        <section class="mb-20">
          <h2 class="text-sm tracking-[0.16em] text-primary-600 dark:text-primary-500">
            LOGO 4 — THE MARK SET IN A BAR · PARKED
          </h2>
          <p class="mt-2 mb-8 max-w-3xl text-sm leading-7 tracking-[0.14em] text-neutral-400">
            The mark with two rects added and nothing else changed: a short lead left, a long tail
            right, both at the eyes' own height. So the header is one bar of eye-height broken into
            four segments, and two of them are eyes. The gaps are the whole mechanism — same height,
            same corners, so an eye butted against the bar would simply BE bar; what separates them
            is the 4 of air the eyes already keep between themselves, used three times instead of
            once. What the bar buys is a datum: alone, a moving eye was a mark doing something, and
            here the same motion is two pieces of the header going and coming back.
          </p>
          <p class="mt-2 mb-8 max-w-3xl text-sm leading-7 tracking-[0.14em] text-neutral-400">
            NOT LIVE, AND THE REASON IS NOT THAT IT LOOKS WORSE. A bar is a LAYOUT. A logo has to
            survive being cropped square, shrunk to a favicon and dropped on a surface that is not
            this one, and a page-width rule can do none of those — at 16px it is a line with two
            specks in it. Logo 3 is the mark; this stays here as the treatment the masthead could
            wear if the page ever wants it, two spans away from returning.
          </p>
          <p class="mt-2 mb-8 max-w-3xl text-sm leading-7 tracking-[0.14em] text-neutral-400">
            THE QUESTION IS THE BAR'S COLOUR. Drawn in the primary it is the loudest object on a
            page whose subject is the list underneath it — and this app already settled that case
            once: when a bar stops being the chosen thing and becomes a header, it drops the
            terracotta, because "look here" cannot be spent on a title and its contents at once.
            B draws it as a translucent tint instead, which is quieter and also the only version
            that survives the theme wash: an opaque bar has a colour of its own to be caught
            wearing while the wash sweeps past it, and a translucent one shows the incoming colour
            through itself and arrives when the page does.
          </p>
          <%!-- THE REAL THING, not a picture of it. The other marks are files and
               an <img> is the honest way to show them; this one IS a CSS
               composition — a flex row whose tail has no length of its own — so a
               fixed-width SVG would be an approximation of the deliverable rather
               than the deliverable. Same .app-rule the header uses, with only
               --rule-ink varied, which is exactly what is being compared.

               FULL WIDTH AND STACKED, because a header shown at 300px in a column
               is not the thing being judged. --%>
          <div class="space-y-10">
            <.rule_demo label="A — BAR IN THE PRIMARY, SHUT EYES" variant={:loud} />
            <.rule_demo label="B — BAR AS A TRANSLUCENT TINT, SHUT EYES" variant={:quiet} />

            <%!-- The two above render the LIVE mark, so they now carry the shut
                 eyes — the swap, seen. This one is the file, which keeps the
                 open squares it was cut with, so both readings are on the page
                 at once rather than one of them being remembered. --%>
            <div>
              <p class="mb-3 text-xs tracking-[0.14em] text-neutral-400">
                C — THE SAME BAR WITH THE ORIGINAL OPEN EYES
              </p>
              <div class="space-y-3">
                <.panel :for={surface <- [:light, :dark]} surface={surface}>
                  <img src={~p"/logo/logo-4.svg"} class="h-auto w-full" alt="Kuisk header bar" />
                </.panel>
              </div>
            </div>
          </div>
        </section>

        <.sheet
          title="LOGO 3 — THE MARK ALONE, EYES SHUT · LIVE AT HOME"
          src={~p"/logo/logo-3.svg"}
          ratio={16 / 6}
          sizes={[64, 28, 14]}
          note="Not a new drawing. The mark's own 16×6 box, the same two eyes at the same two ends
                of it, one unit deep instead of six — drawn on the line a square would close onto,
                so scaleY(6) reopens each into exactly the square it came from. They are drawn shut
                rather than held shut, which is what lets a favicon or a print sheet render the
                closed pair correctly. The twelve-second cycle runs the other way: the second eye
                opens early and holds, and both open together past the middle."
        />

        <.sheet
          title="LOGO 1 — THE MARK"
          src={~p"/logo/logo-1.svg"}
          ratio={48 / 32}
          sizes={[120, 48, 24]}
          note="The app's own face, standing in one 3×3 box of the grid. This surface already says a
                face is two rectangles and a voice is one, and that the mouth is exactly as wide as
                the eyes span end to end — on the module that sentence lands without adjustment. The
                eyes open, wink early and held, then blink together past the middle of a
                twelve-second cycle. The mouth never moves."
        />

        <.sheet
          title="LOGO 2 — THE NAME"
          src={~p"/logo/logo-2.svg"}
          ratio={240 / 80}
          sizes={[100, 50, 30]}
          note="The same modules, five rows deep. Three rows spell O, K and X and very little else —
                S alone needs a top bar, a middle bar, a bottom bar and a stem between each pair,
                which is five rows before you begin. K keeps the reference's one real trick: the arms
                are cells stepped out from the stem, reading as diagonals because they meet at their
                corners. I is one column wide rather than three with the middle filled, so it opens
                no hole in the word."
        />

        <section>
          <h2 class="text-sm tracking-[0.16em] text-primary-600 dark:text-primary-500">
            THE TWO TOGETHER
          </h2>
          <p class="mt-2 mb-8 max-w-3xl text-sm leading-7 tracking-[0.14em] text-neutral-400">
            The live mark against the name. Note what has to be settled before this is a lock-up
            rather than two things next to each other: the wordmark is built on a 16 module and the
            mark on its own 6, so the two agree about colour and corners and about nothing else yet.
            The mark is set at the name's cap height here, which is the least the pairing needs.
          </p>
          <div class="grid gap-6 sm:grid-cols-2">
            <.panel :for={surface <- [:light, :dark]} surface={surface}>
              <div class="flex items-center gap-5">
                <img src={~p"/logo/logo-3.svg"} width="160" height="60" alt="Kuisk mark" />
                <img src={~p"/logo/logo-2.svg"} width="180" height="60" alt="Kuisk" />
              </div>
            </.panel>
          </div>
          <p class="mt-6 text-sm leading-7 tracking-[0.14em] text-neutral-400">
            BOTH DRAW IN currentColor AND DEFAULT TO THE HOUSE TERRACOTTA — primary-600 ON LIGHT,
            primary-500 ON DARK. A HOST THAT SETS --logo-ink OVERRIDES BOTH.
          </p>
        </section>
      </main>
    </div>
    """
  end

  # The four resting shapes, in the order the argument runs: what is live, the
  # two things a straight tilt can produce, and the one adjustment that costs no
  # new vocabulary. The classes live in app.css under THE SHUT-STATE STUDY.
  defp shut_studies do
    [
      {"AS IS", nil},
      {"TILTED, INNER ENDS UP", "head-tilt-up"},
      {"TILTED, INNER ENDS DOWN", "head-tilt-down"},
      {"HEAVIER, NOT TILTED", "head-thick"}
    ]
  end

  # ONE TREATMENT OF THE BAR, ON BOTH SURFACES. Only --rule-ink differs between
  # the two variants — the geometry, the gaps and the mark are the same
  # `.app-rule` the header wears, so what is being compared here is the one
  # decision and not two separate builds of a header.
  attr :label, :string, required: true
  attr :variant, :atom, values: [:loud, :quiet], required: true

  defp rule_demo(assigns) do
    ~H"""
    <div>
      <p class="mb-3 text-xs tracking-[0.14em] text-neutral-400">{@label}</p>
      <div class="space-y-3">
        <.panel :for={surface <- [:light, :dark]} surface={surface}>
          <div class={[
            "app-rule w-full",
            surface == :light && "text-primary-600",
            surface == :dark && "text-primary-500",
            @variant == :loud && "[--rule-ink:currentColor]",
            @variant == :quiet && surface == :light && "[--rule-ink:var(--rule-ink-light)]",
            @variant == :quiet && surface == :dark && "[--rule-ink:var(--rule-ink-dark)]"
          ]}>
            <span class="app-rule-lead"></span>
            <span class="flex"><.head class={nil} /></span>
            <span class="app-rule-tail"></span>
          </div>
        </.panel>
      </div>
    </div>
    """
  end

  # One logo, its argument, and the two surfaces it has to survive. A size given
  # here is a HEIGHT and the width follows from `ratio`, so the artwork's shape
  # is stated once — written out as the viewBox's own two numbers, which is what
  # makes it checkable against the file rather than a figure to be trusted. Both
  # attributes matter: an <img> given one dimension and not the other reflows
  # the page as it loads, and given a wrong pair it silently stretches the mark.
  attr :title, :string, required: true
  attr :note, :string, required: true
  attr :src, :string, required: true
  attr :ratio, :float, required: true
  attr :sizes, :list, required: true

  defp sheet(assigns) do
    ~H"""
    <section class="mb-20">
      <h2 class="text-sm tracking-[0.16em] text-primary-600 dark:text-primary-500">{@title}</h2>
      <p class="mt-2 mb-8 max-w-3xl text-sm leading-7 tracking-[0.14em] text-neutral-400">{@note}</p>

      <div class="grid gap-6 sm:grid-cols-2">
        <.panel :for={surface <- [:light, :dark]} surface={surface}>
          <div :for={h <- @sizes} class="flex flex-col items-center gap-3">
            <img src={@src} width={round(h * @ratio)} height={h} alt={@title} />
            <span class="text-xs tracking-[0.14em] text-neutral-400">
              {round(h * @ratio)}×{h}
            </span>
          </div>
        </.panel>
      </div>
    </section>
    """
  end

  # A mark that only works on one surface is half a mark, so both are always
  # shown and neither follows the page's theme — the point is to see it on the
  # surface you are NOT currently looking at. Square corners: this house does
  # not round a box.
  attr :surface, :atom, required: true
  slot :inner_block, required: true

  defp panel(assigns) do
    ~H"""
    <div class={[
      "flex min-h-48 flex-wrap items-center justify-center gap-10 border p-10",
      @surface == :light && "border-light-300 bg-light-50",
      @surface == :dark && "border-dark-500 bg-dark-950"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
