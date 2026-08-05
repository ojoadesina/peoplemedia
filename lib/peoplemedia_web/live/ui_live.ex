defmodule PeoplemediaWeb.UiLive do
  @moduledoc """
  THE FRAME, AT SIZE, ON A PAGE THAT JUST SCROLLS.

  A workbench for the surface's next shape, at `/ui`, so it can be looked at
  before it replaces the one people are using. Same idea as `/logo`: a route
  that exists to settle a decision and gets deleted with the module once the
  decision is settled.

  ## WHAT IS BEING TRIED

  THE LIST STOPS BEING A LIST. No scroller inside the page, no band across it,
  no settling. Every person is a FRAME — one flat block, the width of the rail —
  and the page scrolls the way a page scrolls. Everything the band did was in
  service of "which one are you looking at", and a frame answers that by being
  the size of the thing it is about instead of by being scrolled into a slot.

  THE FRAME IS A CONTAINER, AND IT HOLDS THE CAPTURE. It was tried the other way
  first — the picture WAS the block, filling it edge to edge with the name laid
  over it under a gradient — and that is a poster, not a person in a list. Every
  row became an advertisement for itself, and the gradient was the tell: a scrim
  exists to keep words readable over an image, which is a problem you only have
  because you put the words on the image.

  SO THE PANEL IS FLAT AND SOLID, and nothing is drawn on top of anything. It
  opens like a drawer: the name stays on its line at the top, and what was
  captured appears underneath it, inside the panel, with the panel's own surface
  still visible around it. Closed, every frame is the same shape whatever is in
  it — which is what a list of PEOPLE looks like, rather than a column of things
  competing to be looked at.

  FOUR STATES: face, voice, still, empty. The mark on the right says which,
  using the vocabulary the rows already speak — one rectangle at four angles,
  plus two eyes for a face.

  ## WHAT IS NOT HERE YET

  FRAMES ARE CAPTURED, and there is nothing to capture with. Until there is,
  the only real media on this surface is what letters carry, so that is what
  fills the frames here — see `frames/1`. Where a person has no such letter the
  frame is empty, which is not a gap in the exhibit: it is the state most of
  them will be in most of the time, and the one the design has to survive.
  """
  use PeoplemediaWeb, :live_view

  alias Peoplemedia.Directory

  # A STAND-IN, AND NAMED AS ONE. There are no captured stills in the data and no
  # way to make one yet, so `still` — a whole quarter of the design — would
  # otherwise be a state nobody could look at.
  #
  # FLAT, WITH NO GRADIENT IN IT. It was a blurred wash, which read as a
  # photograph and therefore as content; the point of a stand-in is that it
  # stands where content will be without pretending to be any. It goes when
  # captures do.
  @still "/images/still-placeholder.svg"

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Frame", frames: frames(socket.assigns[:current_person]))}
  end

  # WHOEVER YOU HOLD, OR EVERYBODY IF YOU HOLD NOBODY. The same two lists the
  # surface itself picks between, without the tabs — this route is about one
  # block, not about which population is under it.
  defp frames(nil), do: Directory.unscopes(nil) |> to_frames()

  defp frames(me) do
    case Directory.scopes(me) do
      [] -> Directory.unscopes(me)
      held -> held
    end
    |> to_frames()
  end

  defp to_frames(people), do: people |> Enum.with_index() |> Enum.map(&to_frame/1)

  # WHAT A ROW KNOWS, TURNED INTO WHAT A FRAME NEEDS. The letterbox summary is
  # the only media on this surface, so `frame` and `media` come straight off it:
  # a face letter makes a face frame, a voice letter a voice frame.
  #
  # A TEXT LETTER MAKES AN EMPTY FRAME, and that is not a shortcut. Words are not
  # a captured moment — Law 5, frames are captured and words are made — so a
  # letter of words leaves the frame exactly as empty as it found it.
  #
  # THE THIRD IN IS THE STILL, and it is the stand-in described above. It is
  # dealt on position rather than at random so the exhibit looks the same twice
  # running; a design you have to reload to compare against itself cannot be
  # compared against itself.
  defp to_frame({item, index}) do
    kind =
      case item[:frame] do
        k when k in ~w(face voice) -> k
        _none -> (rem(index, 3) == 2 && "still") || "empty"
      end

    %{
      id: item[:id],
      name: String.upcase(item[:label] || item[:name]),
      kind: kind,
      media: (kind == "still" && @still) || item[:media]
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-root fixed inset-0 z-0 overflow-y-auto bg-light-50 font-mono dark:bg-dark-950">
      <div class="rail py-(--head-top)">
        <%!-- THE ONE PIECE OF FURNITURE LEFT. No mark, no strapline, no caption
             line, no band — everything that used to stand between the top of the
             page and the first name was there to explain a list, and this is not
             one. What is left says which exhibit you are looking at, and goes
             with the route. --%>
        <p class="mb-(--head-top) text-(length:--sub-type) tracking-(--sub-track) text-neutral-400 dark:text-neutral-500">
          FRAME
        </p>

        <%!-- THE GAP IS THE ONLY SEPARATOR. No rules, no borders, no shadows: two
             flat blocks with air between them read as two things, and anything
             drawn in that air would be a third. --%>
        <ul class="flex flex-col gap-(--frame-gap)">
          <li :for={f <- @frames}>
            <.frame frame={f} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :frame, :map, required: true

  @doc """
  ONE PANEL, FOUR STATES, AND IT OPENS LIKE A DRAWER.

  SQUARE, FLAT, AND SOLID. The drawings this came from are rounded panels — one
  of them glass over a photograph — and none of that survives: every corner on
  this surface is square, and a translucent pane with a blur behind it is
  something laid OVER content. What is kept is the arrangement: a name on the
  left, a mark on the right, on one line.

  THE NAME KEEPS ITS LINE WHEN IT OPENS. That is the whole difference between a
  drawer and a poster. It was at the foot of a picture, over a gradient, and the
  gradient was the tell — a scrim exists to keep words legible over an image,
  which is only a problem if you put the words on the image. Here the words are
  never on the image: the head stays where it was and the capture opens beneath
  it, inside the panel, with the panel's surface still showing around it.

  CLOSED, THEY ARE ALL THE SAME SHAPE. A person with a face captured and a
  person with nothing look identical but for their mark, which is right for a
  list of PEOPLE — the alternative is a column in which whoever last pointed a
  camera at themselves is the loudest thing on your screen.

  EMPTY FRAMES DO NOT OPEN, because there is nothing behind them to see.
  """
  def frame(assigns) do
    ~H"""
    <div
      id={"frame-#{@frame.id}"}
      phx-hook="Frame"
      phx-mounted={JS.ignore_attributes(["class", "style"])}
      data-kind={@frame.kind}
      role={@frame.kind != "empty" && "button"}
      tabindex={@frame.kind != "empty" && "0"}
      aria-label={label_for(@frame)}
      class={["frame relative w-full overflow-hidden", @frame.kind != "empty" && "cursor-pointer"]}
    >
      <%!-- THE HEAD IS THE WHOLE OF A CLOSED FRAME, and it does not move when the
           panel opens. Everything else about this design follows from that. --%>
      <div class="frame-head flex w-full items-center justify-between gap-6 px-(--list-pad)">
        <span class="frame-name min-w-0 truncate text-(length:--frame-type) tracking-(--frame-track)">
          {@frame.name}
        </span>
        <%!-- THE SAME VOCABULARY THE ROWS SPEAK — one rectangle at four angles,
             plus two eyes for a face — so a mark means the same thing wherever it
             is drawn. It is bigger here because the panel is, and for no other
             reason. It stands where the reference puts a `+`, and says more: a
             plus would only tell you the panel opens, which is a thing you
             discover once and then know for every row on the page. --%>
        <.letter_glyph kind={glyph_for(@frame.kind)} class="frame-mark shrink-0" />
      </div>

      <%!-- WHAT WAS CAPTURED, WHEN YOU ASK FOR IT. Inset by the panel's own
           padding rather than run to its edges, so the panel is visibly a thing
           HOLDING a capture rather than a capture with a name printed on it. --%>
      <div :if={@frame.kind != "empty"} class="frame-body px-(--list-pad)">
        <div class="frame-stage">
          <img :if={@frame.kind == "still"} src={@frame.media} alt="" class="frame-media" />
          <video
            :if={@frame.kind == "face"}
            src={@frame.media}
            class="frame-media"
            playsinline
            preload="metadata"
          >
          </video>
          <%!-- A VOICE HAS NO PICTURE, and drawing one for it would be a lie about
               what was captured. Its stage stays the panel's own surface; what
               says it is playing is the line at the foot, which is the only thing
               a recording actually has to show — how far through it you are. --%>
          <audio :if={@frame.kind == "voice"} src={@frame.media} preload="metadata"></audio>
        </div>
      </div>

      <%!-- HOW FAR THROUGH, AS A LINE ON THE PANEL'S OWN EDGE. The same idiom the
           panel's stage already uses, driven by the same `--played`. It is the
           only answer a voice can give, and the only one a face needs while it is
           the thing you are looking at. --%>
      <div :if={@frame.kind in ~w(face voice)} class="frame-progress" aria-hidden="true"></div>
    </div>
    """
  end

  # `still` IS NOT ONE OF THE GLYPH'S WORDS, and the mapping is the point rather
  # than an omission: a still is a moment with no motion and no sound, which is
  # what the struck mouth has always meant — the mouth is there, and it is shut.
  # An empty frame has nothing to say at all, so it gets the mouth stood upright,
  # the same mark a row wears for somebody who is not round.
  defp glyph_for("still"), do: "text"
  defp glyph_for("empty"), do: "away"
  defp glyph_for(kind), do: kind

  defp label_for(%{kind: "empty", name: name}), do: "#{name} — nothing captured"
  defp label_for(%{kind: kind, name: name}), do: "#{name} — play their #{kind}"
end
