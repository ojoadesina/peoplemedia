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

  THE FRAME IS THE CONTENT, NOT A CARD AROUND IT. Empty, it is a flat wash with
  a name on it — the resting state, and the commonest one. Filled, the captured
  moment IS the surface: a still or a face fills the block and the name sits on
  it under a scrim. Nothing is inset, nothing is a thumbnail beside a label.

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

  # A STAND-IN, AND NAMED AS ONE. There are no captured stills in the data and
  # no way to make one yet, so `still` — a whole quarter of the design — would
  # otherwise be a state nobody could look at. Drawn rather than photographed
  # because a drawing cannot be mistaken for real content that arrived from
  # somewhere; it goes when captures do.
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
  ONE BLOCK, FOUR STATES, AND IT OPENS.

  SQUARE, AND FLAT. The shape it is drawn from is a rounded glass panel floating
  over a photograph, and neither half of that survives here: every corner on this
  surface is square, and a translucent panel with a blur behind it is a pane laid
  OVER content, when this block IS the content. Rounded and glossy it would be a
  card about a person; flat and square it is the moment itself, with their name
  on it.

  THE NAME SITS AT THE FOOT, not in the middle, and the mark sits opposite it on
  the same line. That is the one thing taken unchanged from the reference: a name
  low on a picture reads as a caption belonging to the picture, and a name
  centred in a box reads as a label on a container.

  IT OPENS INTO ITSELF. Pressed, the block grows and the clip inside it plays —
  no room, no overlay, no navigation. The frame is already the right shape for
  its contents, so opening it is a matter of giving it more of the page rather
  than moving what is in it somewhere else. Empty frames do not open, because
  there is nothing behind them to see.
  """
  def frame(assigns) do
    ~H"""
    <div
      id={"frame-#{@frame.id}"}
      phx-hook="Frame"
      phx-mounted={JS.ignore_attributes(["class"])}
      data-kind={@frame.kind}
      role={@frame.kind != "empty" && "button"}
      tabindex={@frame.kind != "empty" && "0"}
      aria-label={label_for(@frame)}
      class={[
        "frame relative flex w-full flex-col justify-end overflow-hidden",
        "px-(--list-pad) pb-(--list-pad)",
        @frame.kind != "empty" && "cursor-pointer"
      ]}
    >
      <%!-- THE PICTURE IS THE BACKGROUND, in the literal sense: it is behind
           everything and it is the whole block. A still is an <img> and a face is
           a <video> showing its first frame until it is asked to move, which is
           what a poster IS — so no separate poster is needed and no still stands
           in for a face that is right there. --%>
      <img :if={@frame.kind == "still"} src={@frame.media} alt="" class="frame-media" />
      <video
        :if={@frame.kind == "face"}
        src={@frame.media}
        class="frame-media"
        playsinline
        preload="metadata"
        muted
      >
      </video>
      <%!-- A VOICE HAS NO PICTURE, and drawing one for it would be a lie about
           what was captured. It gets the same wash an empty frame gets and is
           told apart by its mark — which is the argument for having marks at
           all. What it does have is a LENGTH, so opening it fills the block as
           it plays: see .frame.is-open[data-kind="voice"]. --%>
      <audio :if={@frame.kind == "voice"} src={@frame.media} preload="metadata"></audio>
      <div :if={@frame.media && @frame.kind in ~w(still face)} class="frame-scrim"></div>

      <div class="relative flex w-full items-end justify-between gap-6">
        <span class="frame-name min-w-0 truncate text-(length:--frame-type) tracking-(--frame-track)">
          {@frame.name}
        </span>
        <%!-- THE SAME VOCABULARY THE ROWS SPEAK — one rectangle at four angles,
             plus two eyes for a face — so a mark means the same thing wherever it
             is drawn. It is bigger here because the block is, and for no other
             reason. --%>
        <.letter_glyph kind={glyph_for(@frame.kind)} class="frame-mark shrink-0" />
      </div>
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
