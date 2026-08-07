defmodule PeoplemediaWeb.UiLive do
  @moduledoc """
  A HOMEPAGE OF POSTS, ONE PHONE WIDE, AT `/ui`.

  A workbench, like `/logo` — a route that exists to look at a shape before
  anything is decided about it, and gets deleted with the module once it is.

  ## WHAT IS BEING TRIED

  ONE COLUMN, PHONE-WIDTH, CENTRED. The column is sized for a phone and pinned
  to the middle of whatever it is opened on, so the design is only ever judged
  at the width it is drawn for. There is no wide layout and no breakpoint that
  reaches for one: a second arrangement at 64rem would be a second design, and
  this page has one design in it.

  THE PAGE JUST SCROLLS. No fixed shell, no scroller inside a scroller, no band
  — the browser's own scroll, which is the one a thumb already knows.

  AN ITEM IS TWO BLOCKS: A FRAME, AND WHAT THEY SAID. They were one panel,
  which made the person a property of the post — a byline, the small print at
  the top of the thing you are actually here for. Split, the person is a block
  in their own right standing over a block of their own words, and the column
  reads as PEOPLE WITH THINGS UNDER THEM rather than posts that happen to be
  signed.

  THE FRAME IS THE CAPTURE AND WHAT IT IS WORTH TO YOU. A name on the left; the
  age and `letter_flow/1` — which way the letters last went and whether they
  landed — trailing on the right. The kind mark that used to sit between them is
  gone: it named what a frame held, and the frame now shows what it holds
  directly, so the mark had become a caption on a picture you are already looking
  at.

  WHERE A FACE WAS CAPTURED, THE WHOLE FRAME IS THAT VIDEO — edge to edge,
  playing, with the name and the marks laid over it. A face is what a person
  captured OF themselves, so on their own frame it is the substrate rather than
  something attached to one. The scrim and the text-shadow that keep the words
  legible over it are the app's own, copied off `.stage.is-face` and
  `.panel-item[data-kind="face"]` rather than invented here.

  AND A VOICE FILLS ITS FRAME AS FAR AS YOU HAVE HEARD IT. Not a scrubber on the
  bottom edge: a scrubber is a control drawn small because it is furniture, and
  there is nothing here to drag. The frame is reporting, so the frame is what
  changes — a sage wash at 15% running left to right, read the way you read a
  glass rather than the way you read a dial. Nothing at all at zero, because an
  untouched voice is an untouched panel.

  THE ROUND IS ONE PANEL CARRYING TWO THINGS: what it is called and what is in
  it. A room name at its own width — a forum title, the thing you would say to
  tell somebody which round you meant — and the word cards trailing at the right.

  A LEAN MEANS "THERE IS MORE HERE THAN YOU CAN SEE". The word cards pile on one
  spot and lean 6 degrees apart whenever a round holds more than one. Two leaves
  and no more: the lean says MORE THAN ONE, the digit on the front says how many.

  EVERY BLOCK IS A FIXED HEIGHT AND NOTHING INSIDE ONE IS LOAD-BEARING. A round
  holding twenty-four words is exactly as tall as one holding none, so the
  column's beat never becomes a function of what people happened to do in it.

  THE MEDIA IS PUBLIC AND BORROWED. There is still nothing in this app to capture
  with, so the faces are ~1MB CC-licensed clips from test-videos.co.uk. They are
  real media rather than drawn stand-ins, which is the only way to judge type over
  a moving picture, and they are external URLs — this page needs a network to look
  right. They go the day captures arrive.

  NEUTRAL, NOT THE WARM RAMP. The surface's `light-*` cream belongs to the
  surface. A feed reads as a feed in true greys — every social column you have
  ever scrolled is untinted — and the theme keeps `neutral-*` for exactly this:
  chrome that must not pick up a temperature.

  SQUARE, FLAT, AND COUPLED IN THE GAP. Every panel is solid and square, and a
  short stroke standing in the 0.5rem between a frame and its round says the two
  are one item. It sits 1.5rem in from the edge, clear of the panels' own 1rem
  gutter, so it reads as a mark placed deliberately in the space rather than as
  either edge or type continuing. Outside the blocks it was a margin rule
  annotating the pair from beyond it; centred, a flowchart connector pointing
  rather than continuing; flush to the
  edge, merely the edge repeating itself. The reference this was drawn from has
  rounded panels and those are still not copied: this house does not round a box,
  and one page of soft corners would put every other surface out of step with it.

  ## THE DATA IS FAKE, AND ONLY LIVES HERE

  `@posts` is a hand-written list in this module. Nothing is read from the
  database and nothing is written back — the point is the block, not the wiring,
  and inventing a schema for a shape that has not been chosen yet is how
  exhibits turn into features by accident.
  """
  use PeoplemediaWeb, :live_view

  # FOURTEEN, BECAUSE SIX DOES NOT SCROLL. A feed short enough to take in at a
  # glance is a mock-up of a feed: you cannot tell whether the rhythm holds,
  # whether the marks read as quiet at density, or whether two items ever get
  # confused for one. The column has to run past the fold before any of that is
  # answerable, and running past the fold is most of what makes a page look
  # real.
  #
  # THE AGES RUN DOWN. Newest first and strictly descending, because that is the
  # one ordering a feed is allowed to have and the eye checks it without being
  # asked — a column out of order reads as broken long before you work out why.
  #
  # THREE BODIES OVERRUN THEIR LINE, so the truncation is on the page rather
  # than taken on trust — a sheet of sentences that all happen to fit proves
  # nothing about the block that has to hold them.
  #
  # `letter` IS THE SURFACE'S OWN SHAPE, not a field invented here: what
  # `Directory.summarise/1` builds — `:read`, `:unread`, or nil for "no such
  # letter, so draw no arrow", which is a third answer and must not collapse into
  # either of the others.
  #
  # `room` IS A FORUM TITLE AND IS WRITTEN LIKE ONE. Short, deliberate, the thing
  # you would say out loud to name which round you meant — not a summary of what
  # was said in it. A few run long enough to truncate, because a
  # character-limited field always has someone testing the limit.
  #
  # THE LOUD STATES ARE DEALT THIN. Two unopened letters in fourteen rows, because
  # terracotta means "this one is asking for you" and a column where a third of
  # the rows ask has no way left to say that one does.
  #
  # HALF OF THEM CARRY NO ARROWS AT ALL. You have never written to most people
  # you can see, and a flow drawn on every row would say the opposite — it would
  # make a page of strangers look like a page of correspondence.
  #
  # AND CAPTURES ARE RARE. Three faces and three voices in fourteen: if half the
  # column were video the page would be lying about how often anybody actually
  # points a camera at themselves, and the ones that do would stop standing out.
  #
  # MOODS ARE MOSTLY SET BUT NOT ALWAYS, and they spread across six of the seven
  # families rather than clustering on the pleasant ones — a sheet where everyone
  # is joyful cannot show whether the wash works at the other end of the palette.
  #
  # THE AGES ARE ALL SHORT TOKENS. "YESTERDAY" was here and it was the loudest
  # thing on its line — nine tracked characters answering a question nobody had
  # asked yet. An age is an aside, and an aside that outruns the name it trails
  # is not one.
  @posts [
    %{
      id: 1,
      name: "ZAINAB",
      room: "ANYONE UP",
      age: "2M",
      video: nil,
      progress: 0.0,
      words: 6,
      letter: %{incoming: :unread, outgoing: nil}
    },
    %{
      id: 2,
      name: "ALEX",
      room: "MUM'S KITCHEN",
      age: "8M",
      video: nil,
      progress: nil,
      words: 3,
      letter: %{incoming: :read, outgoing: nil}
    },
    %{
      id: 3,
      name: "MARCUS",
      room: "THE JOB",
      age: "14M",
      video:
        "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4",
      progress: nil,
      words: 2,
      letter: nil
    },
    %{
      id: 4,
      name: "DANIEL",
      room: "THE LONG WAY",
      age: "26M",
      video: nil,
      progress: nil,
      words: 0,
      letter: %{incoming: :read, outgoing: :read}
    },
    %{
      id: 5,
      name: "PRIYA",
      room: "THIRD COFFEE",
      age: "41M",
      video: nil,
      progress: 1.0,
      words: 5,
      letter: nil
    },
    %{
      id: 6,
      name: "NAOMI",
      room: "TOO QUIET",
      age: "1H",
      video: nil,
      progress: 0.41,
      words: 4,
      letter: %{incoming: :read, outgoing: nil}
    },
    %{
      id: 7,
      name: "SAM",
      room: "THE 8:14",
      age: "2H",
      video: nil,
      progress: nil,
      words: 1,
      letter: nil
    },
    %{
      id: 8,
      name: "GRACE",
      room: "BREAD, ATTEMPT FOUR",
      age: "3H",
      video: "https://test-videos.co.uk/vids/jellyfish/mp4/h264/360/Jellyfish_360_10s_1MB.mp4",
      progress: nil,
      words: 12,
      letter: %{incoming: :read, outgoing: nil}
    },
    %{
      id: 9,
      name: "TOBI",
      room: "DAY THREE OF RAIN",
      age: "4H",
      video: nil,
      progress: nil,
      words: 0,
      letter: %{incoming: :read, outgoing: :unread}
    },
    %{
      id: 10,
      name: "MUM",
      room: "YOUR SISTER",
      age: "6H",
      video: nil,
      progress: nil,
      words: 2,
      letter: %{incoming: :unread, outgoing: nil}
    },
    %{
      id: 11,
      name: "KEMI",
      room: "FINISHED IT",
      age: "9H",
      video: nil,
      progress: nil,
      words: 0,
      letter: nil
    },
    %{
      id: 12,
      name: "OMAR",
      room: "NOTHING TO REPORT",
      age: "14H",
      video: nil,
      progress: nil,
      words: 0,
      letter: nil
    },
    %{
      id: 13,
      name: "IDRIS",
      room: "SIX WEEKS ON ONE WALL",
      age: "1D",
      video: "https://test-videos.co.uk/vids/sintel/mp4/h264/360/Sintel_360_10s_1MB.mp4",
      progress: nil,
      words: 24,
      letter: nil
    },
    %{
      id: 14,
      name: "ADA",
      room: "BOXES EVERYWHERE",
      age: "2D",
      video: nil,
      progress: nil,
      words: 7,
      letter: %{incoming: nil, outgoing: :read}
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home", posts: @posts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh bg-neutral-50 font-mono text-neutral-950 dark:bg-dark-950 dark:text-dark-50">
      <%!-- THE COLUMN. 26rem is a large phone with the gutter already taken off
           it, and `mx-auto` is what puts it in the middle of a screen bigger
           than that. Nothing else on the page has a width. --%>
      <main class="mx-auto w-full max-w-[26rem] px-4 pt-8 pb-16">
        <ul class="flex flex-col gap-7">
          <li :for={post <- @posts} class="flex flex-col">
            <.frame post={post} />

            <%!-- THE JOIN: IN THE GAP, INSET FROM THE LEFT. It stands a full
                 gutter in — the same 1rem the panels hold their own words at —
                 so it starts where the name above it starts and the sentence
                 below it starts. Flush to the panel edge it was merely the edge
                 continuing, which says nothing the edge was not already saying;
                 a gutter in, it stands with the type and reads as belonging to
                 the words rather than to the box.

                 AND IT IS 2px, NOT A HAIRLINE. A 1px stroke 8px long is a
                 rounding error on any screen that is not perfectly scaled — it
                 was invisible on a phone and half-invisible on a laptop. It is
                 a small mark and it has one job, so it is drawn at a weight that
                 survives being looked at, in an ink that carries on both grounds.

                 IT IS ALSO THE GAP. The 0.5rem is this element's height rather
                 than a `gap-2` on the list, so the air between a frame and its
                 word and the line crossing that air are one measurement and
                 cannot drift apart. --%>
            <div class="flex h-2 pl-6" aria-hidden="true">
              <span class="w-0.5 bg-neutral-400 dark:bg-dark-600"></span>
            </div>

            <.round_bar post={post} />
          </li>
        </ul>
      </main>
    </div>
    """
  end

  # THE FRAME: WHO, ON ONE LINE. A person, and nothing about what they said —
  # the whole reason this is not a header row any more is that it answers on its
  # own.
  #
  # THE AVATAR IS GONE. A square with an initial in it was a stand-in for a
  # photograph — it said nothing except that a picture was expected here and
  # none arrived.
  #
  # AND THE MARK MOVED OUT OF ITS PLACE, over to the right with the age and the
  # arrows. Hard left it was the first thing on every line, which put a
  # SECONDARY answer — what kind this is — in front of the primary one, the
  # name. Names now start on one edge with nothing before them, which is what
  # makes a column of people scannable: fourteen first characters in a straight
  # line, and the eye runs down them without stopping.
  #
  # THE THREE OF THEM ARE ONE TRAILING GROUP: kind, age, flow — what it is, when
  # it was, how it stands with you. All three are answers you want AFTER you
  # know who, and they now sit where you look after reading a name.
  #
  # THE HANDLE IS GONE TOO. `@name` is one particular app's furniture, and this
  # surface has no use for it: a passport already carries a handle, and printing
  # it beside the name says the same thing twice in a smaller grey.
  #
  # THE FONT-SIZE IS SET ON THE ROW because both marks take their width in `em`.
  # A caller that leaves it unset gets marks sized against the page default,
  # standing in a narrower column than the words beside them.
  #
  # AND text-md IS THE SOCIAL SIZE, ARRIVED AT HONESTLY. X and Facebook set a
  # name at 15px, which is this theme's --text-lg exactly, and that is what was
  # here. But theirs is sentence case and untracked, and ours is CAPITALS at
  # 0.1em — both of which add apparent size — so the same 15px read a size
  # larger than the apps it was borrowed from. 14px tracked lands where their
  # 15px plain does, which is the number that was actually wanted.
  attr :post, :map, required: true

  defp frame(assigns) do
    ~H"""
    <div class={[
      "relative flex h-14 items-center gap-3 overflow-hidden px-4 text-md",
      (@post.video && "text-light-50") || "bg-neutral-100 dark:bg-dark-900"
    ]}>
      <%!-- A FACE FRAME IS THE CAPTURE. Not a panel with a thumbnail in it — the
           whole container is the video, edge to edge, and everything the frame
           says is laid over it. A face is what somebody captured of themselves,
           so on their frame it is the substrate rather than an attachment to
           one.

           MUTED, LOOPED, INLINE, AND NOT LAZY ABOUT IT. A still would be a
           poster and the point is that this moves; `playsinline` is what stops
           iOS taking it fullscreen the moment it starts.

           THE SCRIM AND THE SHADOW ARE THE APP'S OWN ANSWER, copied rather than
           reinvented: `.stage.is-face .stage-fill` lays this exact ramp over a
           face capture and `.panel-item[data-kind="face"] span` carries this
           exact text-shadow. Both, not either — the wash holds the light end of
           the picture down and the shadow holds the type up over whatever the
           wash misses, and a video is a moving background so nothing static can
           be relied on to be dark where a word happens to be. --%>
      <video
        :if={@post.video}
        src={@post.video}
        autoplay
        muted
        loop
        playsinline
        aria-hidden="true"
        class="absolute inset-0 size-full object-cover"
      >
      </video>
      <span
        :if={@post.video}
        class="absolute inset-0 bg-linear-to-b from-black/65 via-black/35 to-black/25"
        aria-hidden="true"
      >
      </span>

      <%!-- HOW FAR INTO THE VOICE YOU GOT, AS THE PANEL ITSELF. It was a 2px
           rule on the bottom edge, which is a scrubber — a control, drawn small
           because it is furniture. This is not a control and there is nothing to
           drag: it is the frame REPORTING, so the frame is what changes. The
           played part of the voice is the filled part of the panel, left to
           right, and you read it the way you read a glass rather than the way
           you read a dial.

           A WASH, NOT A COLOUR. Sage at 15% over the panel — the same strength
           the moods are held at everywhere else on this surface — because it
           spans the whole block and anything stronger would make the name
           unreadable on the played half and fine on the unplayed one, which is
           the worst thing a background can do to a line of type.

           SAGE, BECAUSE IT REPORTS. The ↑ arrow already takes this hue to say a
           letter of yours landed; progress is the same kind of statement about
           the same kind of thing. Warm asks, cool reports — terracotta stays on
           the one thing asking.

           NOTHING AT ALL AT ZERO. An untouched voice is an untouched panel. The
           mark already says this is a voice, so there is no need for an empty
           track to say it a second time. --%>
      <span
        :if={@post.progress}
        class="absolute inset-y-0 left-0 bg-secondary-600/15 dark:bg-secondary-400/15"
        style={"width: #{round(@post.progress * 100)}%"}
        aria-hidden="true"
      >
      </span>

      <p class={[
        "relative min-w-0 flex-1 truncate tracking-[0.1em]",
        @post.video && "on-capture"
      ]}>
        {@post.name}
      </p>

      <%!-- THE AGE WAS TOO LOUD FOR AN ASIDE, and the size was not the reason.
           At 0.16em of tracking a three-character age occupied a name's worth of
           rail and read as a second heading; the tracking is now 0.08em, which
           is enough to keep capitals from touching and not enough to make a
           word out of them. The grey and the 12px were always right. --%>
      <span class={[
        "relative shrink-0 text-sm tracking-[0.08em]",
        (@post.video && "text-light-100 on-capture") || quiet()
      ]}>
        {@post.age}
      </span>

      <%!-- YES, THE ARROWS WERE TOO SMALL — and they were the right size, which
           is why it was worth tracking down. They are drawn at 1.05em, tuned
           against the list's --row-type, and that clamps between 16px and 20px:
           in the app they land at 17-21px. This row is text-md, 14px, so the
           same 1.05em came out at under 15px — a mark tuned to be quiet at 20px
           is merely hard to find at 15.

           SO THE PAIR IS GIVEN ITS OWN BASE rather than the row's. text-xl puts
           them back at 16.8px, the bottom of the range they were drawn for, and
           the name keeps the 14px that was chosen for it. Two things that need
           different sizes should not be made to share one. --%>
      <.letter_flow
        :if={@post.letter}
        letter={@post.letter}
        class={[
          "relative text-xl",
          @post.video && "on-capture-mark"
        ]}
      />
    </div>
    """
  end

  # THE ROUND: WHAT IT IS CALLED, HOW IT FEELS, AND WHAT IS IN IT.
  #
  # ONE PANEL HOLDING TWO THINGS: a name and a deck of word cards. The round is
  # one object and reads as one.
  #
  # THE NAME IS A ROOM'S NAME, NOT A SENTENCE. It behaves like a forum title —
  # short, given deliberately, the thing you would say to somebody to tell them
  # which round you meant. Its block takes only the width the title needs,
  # because a title padded out to fill a rail stops reading as a title and starts
  # reading as a field.
  #
  attr :post, :map, required: true

  defp round_bar(assigns) do
    ~H"""
    <div class="flex h-16 items-center gap-3 bg-neutral-100 px-4 dark:bg-dark-900">
      <p class="min-w-0 truncate text-md tracking-[0.08em] text-neutral-900 dark:text-dark-100">
        {@post.room}
      </p>

      <.word_cards post={@post} />
    </div>
    """
  end

  # HOW MANY WORD BARS ARE INSIDE. A word is threaded, so it is a door onto a
  # stack of them, and the count is the one thing worth saying about a stack
  # before you open it: whether there is a conversation in there or just the
  # sentence you are looking at.
  #
  # IT IS ABSENT, NOT ZERO, WHEN THERE IS NOTHING INSIDE. A column of "0" badges
  # is fourteen rows reporting an absence, and Law 1 is that absence is silent.
  #
  # MORE THAN ONE AND THEY STACK. It does the job a digit alone cannot: the
  # number tells you how many once you have read it, the stack tells you there is
  # more than one before you have. One card is one thing; two cards are a pile,
  # at any size and any distance.
  #
  # THE TWO ARE TILTED APART, NOT SLID APART. Offsetting the back card by a few
  # pixels leaves both upright and parallel, which does not read as two cards —
  # it reads as one card with a printing error, or as a drop shadow that forgot
  # to be soft. Rotating them in OPPOSITE directions around a shared centre makes
  # the corners of the one behind emerge on both sides at once, and two shapes at
  # different angles can only be two shapes.
  #
  # A SINGLE CARD DOES NOT LEAN. There is nothing behind it, so the tilt would be
  # decoration — and the tilt is the whole signal.
  #
  # THE BACK CARD IS ONE STEP QUIETER, in both liveries. It has to read as
  # BEHIND, and depth on a flat surface with no shadows in it can only come from
  # tone.
  attr :post, :map, required: true

  defp word_cards(assigns) do
    ~H"""
    <span :if={@post.words > 0} class="relative ml-auto shrink-0">
      <span
        :if={@post.words > 1}
        class={[
          "absolute inset-0 rotate-6",
          (unread?(@post) && "bg-primary-400 dark:bg-primary-700") ||
            "bg-neutral-300 dark:bg-dark-700"
        ]}
        aria-hidden="true"
      >
      </span>

      <%!-- IT LIGHTS WHEN A LETTER IS UNOPENED. Grey was reasoned from "a thread
           that exists is not a thread asking for you" — true of the thread, false
           of this item: the ↓ on the frame above is already terracotta, and a
           grey deck beneath it said the words waiting inside were a separate,
           calmer matter. They are not, they are what is waiting.

           A FILL, NOT INK. The arrow is a drawn shape and takes terracotta as
           colour; this is a card, so it takes terracotta as its GROUND. A card
           that only recoloured its digit would be the faintest thing on the row,
           which is backwards — it holds the number. --%>
      <span class={[
        "relative flex h-5 min-w-5 items-center justify-center px-1.5 text-sm tracking-[0.08em]",
        @post.words > 1 && "-rotate-6",
        (unread?(@post) && "bg-primary-600 text-light-50 dark:bg-primary-500 dark:text-dark-950") ||
          ["bg-neutral-200 dark:bg-dark-800", quiet()]
      ]}>
        {@post.words}
      </span>
    </span>
    """
  end

  # THE ASIDE VOICE, declared once. The age and a resting deck are the same remark
  # at the same volume, and two copies of one grey is one chance for them to stop
  # matching.
  defp quiet, do: "text-neutral-400 dark:text-neutral-500"

  # THE MARK AND THE ↓ LIGHT FOR THE SAME REASON AND MUST AGREE. Both mean "an
  # unopened letter is here", so the answer is read off the letter rather than
  # stored twice — a `lit` field of its own could disagree with the arrow beside
  # it, and terracotta appearing on one but not the other is a bug you would
  # never spot on a static sheet.
  defp unread?(%{letter: %{incoming: :unread}}), do: true
  defp unread?(_read), do: false
end
