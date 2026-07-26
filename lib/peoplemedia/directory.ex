defmodule Peoplemedia.Directory do
  @moduledoc """
  The people, the places, and the presences they left.

  FIXTURE DATA, deliberately. This app has no database and does not depend on
  Ecto: the surface is being designed before the spine is built, so nothing here
  is loaded, only rendered. The MEDIA is real, though — fetched from Wikimedia
  Commons at play time — so what you see behaves like the thing rather than
  miming it.

  It lives in its own module so a LiveView can be about the SURFACE. When the
  spine does arrive, this is the one file that changes and every view that reads
  it keeps working.
  """

  # Wikimedia Commons serves a permanent MP3/WebM transcode alongside every
  # upload. We point at those rather than the .ogg and .webm originals for one
  # blunt reason: Safari cannot play Ogg Vorbis at all, and the originals are
  # 9–14 MB apiece for a screen that is forty-five pixels square. The 360p
  # transcodes are roughly a tenth of that.
  @commons "https://upload.wikimedia.org/wikipedia/commons/transcoded"

  # A USER is a label YOU gave them, the name they came with, and what their
  # frame is currently carrying. The label leads because it is how you actually
  # think of them; the name follows, faded, and only once the row is in the band.
  #
  # STATE and FRAME are two different questions and are kept apart on purpose.
  # State asks about the PERSON and the line to them; frame asks what is coming
  # THROUGH it. The two are orthogonal, and every combination means something:
  #
  #   "absent"  — not reachable. The screen drains to neutral rather than to a
  #               paler terracotta, because terracotta is the colour of someone
  #               being there and a weak version of it reads as a weak signal
  #               rather than as nobody.
  #   "present" — reachable. The screen keeps its colour and sits still unless
  #               there is media to move it.
  #   "live"    — the line is open right now. The screen breathes EVEN WITH
  #               NOTHING COMING THROUGH, which is the whole point of the state:
  #               a live line with no voice and no face is still a live line,
  #               and a still screen could not say so. The frame breathes with
  #               it, on the same period, so the two read as one thing being
  #               alive rather than two things blinking.
  #
  # Absence pairs with an empty frame here for the obvious reason — you cannot
  # be away and talking — but nothing in the code enforces that, because a line
  # can perfectly well carry a recording of someone who has since gone. Live is
  # deliberately spread across all three frame modes below, so the empty case
  # that proves the state is worth having actually appears.
  #
  # FRAME is the state of the line to them, and it is deliberately three-valued
  # rather than a boolean, because "nothing coming through" and "audio coming
  # through" are different facts and the frame renders them differently:
  #
  #   "empty" — no signal. The screen sits still.
  #   "voice" — audio only. The screen breathes, because there is nothing to
  #             look at and the sound is the whole message.
  #   "face"  — video. The screen holds still and shows it.
  #
  # THE MEDIA IS REAL, and chosen to match what this app is for. The voices come
  # from Commons' Voice Intro Project, where people record a short introduction
  # of themselves — the closest thing to a real first contact that exists under
  # a free licence. The faces come from Wikitongues, whose recordings are single
  # speakers talking to camera. Every clip is under a minute. Licences run CC0
  # to CC BY-SA; attribution lives in ATTRIBUTION.md at the repo root.
  @scopes [
    %{
      label: "MUM",
      name: "SARAH",
      state: "present",
      frame: "voice",
      media:
        "#{@commons}/4/4f/Simone_Giertz_introducing_herself.ogg/" <>
          "Simone_Giertz_introducing_herself.ogg.mp3"
    },
    %{
      label: "DAD",
      name: "MICHAEL",
      state: "present",
      frame: "face",
      media:
        "#{@commons}/6/67/WIKITONGUES-_Paulus_speaking_Mentuka.webm/" <>
          "WIKITONGUES-_Paulus_speaking_Mentuka.webm.360p.vp9.webm"
    },
    %{
      label: "BIG BROTHER",
      name: "DANIEL OLUWASEUN",
      state: "present",
      frame: "voice",
      media: "#{@commons}/0/0a/Charles_Duke_Intro.ogg/Charles_Duke_Intro.ogg.mp3"
    },
    %{label: "BROTHER", name: "JOSEPH", state: "absent", frame: "empty", media: nil},
    %{
      label: "SISTER",
      name: "AMAKA",
      state: "live",
      frame: "face",
      media:
        "#{@commons}/0/01/WIKITONGUES-_Hermica_speaking_Bengape.webm/" <>
          "WIKITONGUES-_Hermica_speaking_Bengape.webm.360p.vp9.webm"
    },
    %{
      label: "GRANDMA",
      name: "ROSE",
      state: "live",
      frame: "voice",
      media: "#{@commons}/c/ca/Robin_Owain_en_Voice.ogg/Robin_Owain_en_Voice.ogg.mp3"
    },
    %{label: "COACH", name: "IBRAHIM", state: "live", frame: "empty", media: nil},
    %{
      label: "BEST FRIEND",
      name: "TUNDE ADEBAYO",
      state: "live",
      frame: "face",
      media:
        "#{@commons}/3/31/WIKITONGUES-_C%C3%A9lestin_speaking_Kilega.webm/" <>
          "WIKITONGUES-_C%C3%A9lestin_speaking_Kilega.webm.360p.vp9.webm"
    },
    %{label: "NEIGHBOUR", name: "ELENA", state: "absent", frame: "empty", media: nil},
    %{
      label: "COUSIN",
      name: "KEMI",
      state: "live",
      frame: "voice",
      media:
        "#{@commons}/4/46/Dan_Barker_introducing_himself.ogg/" <>
          "Dan_Barker_introducing_himself.ogg.mp3"
    },
    %{label: "UNCLE", name: "PETER", state: "absent", frame: "empty", media: nil},
    %{
      label: "AUNT",
      name: "BLESSING",
      state: "present",
      frame: "face",
      media:
        "#{@commons}/0/04/WIKITONGUES-_Donald_speaking_Tswana.webm/" <>
          "WIKITONGUES-_Donald_speaking_Tswana.webm.360p.vp9.webm"
    },
    %{
      label: "MENTOR",
      name: "ADEOLA",
      state: "present",
      frame: "voice",
      media:
        "#{@commons}/e/ed/Richard_Rogers_-_voice_-_en.ogg/Richard_Rogers_-_voice_-_en.ogg.mp3"
    },
    %{label: "ROOMMATE", name: "LUCAS", state: "present", frame: "empty", media: nil},
    %{label: "BOSS", name: "HANNAH", state: "absent", frame: "empty", media: nil},
    %{label: "DOCTOR", name: "NGOZI", state: "live", frame: "empty", media: nil},
    %{label: "BARBER", name: "FEMI", state: "absent", frame: "empty", media: nil},
    %{label: "PASTOR", name: "EMMANUEL", state: "present", frame: "empty", media: nil},
    %{label: "TEAMMATE", name: "CHIDI", state: "absent", frame: "empty", media: nil}
  ]

  # THE UNSCOPED WORLD — everyone you have NOT made a relationship with. They
  # carry a name but no label, because a label is a name YOU gave someone and
  # you have given these none. This is the discovery surface: the same live
  # frame, the same three states, but people you do not yet hold. The SCOPED
  # button flips the list between the two — the ones you keep, and the rest.
  @unscopes [
    %{
      label: nil,
      name: "AMINA",
      state: "live",
      frame: "face",
      media:
        "#{@commons}/8/8e/WIKITONGUES-_Sedang_speaking_Iban.webm/WIKITONGUES-_Sedang_speaking_Iban.webm.360p.vp9.webm"
    },
    %{
      label: nil,
      name: "LEV",
      state: "live",
      frame: "voice",
      media: "#{@commons}/9/96/Andy_Mabbett_voice.ogg/Andy_Mabbett_voice.ogg.mp3"
    },
    %{
      label: nil,
      name: "PRIYA",
      state: "present",
      frame: "voice",
      media: "#{@commons}/b/bb/Bettany_Hughes_voice.ogg/Bettany_Hughes_voice.ogg.mp3"
    },
    %{
      label: nil,
      name: "TARKHAN",
      state: "live",
      frame: "face",
      media:
        "#{@commons}/2/26/WIKITONGUES-_Tarkhan_speaking_Jek.webm/WIKITONGUES-_Tarkhan_speaking_Jek.webm.360p.vp9.webm"
    },
    %{label: nil, name: "SOPHIE", state: "absent", frame: "empty", media: nil},
    %{
      label: nil,
      name: "JERIES",
      state: "present",
      frame: "face",
      media:
        "#{@commons}/c/c9/WIKITONGUES-_Jeries_speaking_Syriac.webm/WIKITONGUES-_Jeries_speaking_Syriac.webm.360p.vp9.webm"
    },
    %{
      label: nil,
      name: "MATEO",
      state: "live",
      frame: "voice",
      media: "#{@commons}/0/01/David_Lammy_voice.ogg/David_Lammy_voice.ogg.mp3"
    },
    %{
      label: nil,
      name: "YERNUR",
      state: "present",
      frame: "face",
      media:
        "#{@commons}/2/20/WIKITONGUES-_Yernur_speaking_Kazakh.webm/WIKITONGUES-_Yernur_speaking_Kazakh.webm.360p.vp9.webm"
    },
    %{label: nil, name: "HANA", state: "absent", frame: "empty", media: nil},
    %{
      label: nil,
      name: "OMAR",
      state: "present",
      frame: "voice",
      media: "#{@commons}/e/ec/David_Harewood_voice.ogg/David_Harewood_voice.ogg.mp3"
    },
    %{
      label: nil,
      name: "ULADZISLAU",
      state: "live",
      frame: "face",
      media:
        "#{@commons}/e/ea/WIKITONGUES-_Uladzislau_speaking_Belarusian.webm/WIKITONGUES-_Uladzislau_speaking_Belarusian.webm.360p.vp9.webm"
    },
    %{
      label: nil,
      name: "FREYA",
      state: "present",
      frame: "voice",
      media: "#{@commons}/0/0f/Alison_Balsom_voice.ogg/Alison_Balsom_voice.ogg.mp3"
    },
    %{label: nil, name: "RIZKI", state: "absent", frame: "empty", media: nil},
    %{
      label: nil,
      name: "NOA",
      state: "present",
      frame: "voice",
      media: "#{@commons}/f/fa/Brian_Schmidt_voice.ogg/Brian_Schmidt_voice.ogg.mp3"
    },
    %{label: nil, name: "DIEGO", state: "absent", frame: "empty", media: nil}
  ]

  # WORLD COUNTRIES — the LOCATION list. A scroll of places rather than people;
  # what settles in the band is a country, and its box shows how many are
  # present THERE right now instead of a face or a voice. Finland is the default
  # until another is chosen. The list stays sorted the way the frame reads it —
  # a plain roll of the world, no counts baked into the order.
  # TWO POPULATIONS PER PLACE, not one headcount. A country answers two separate
  # questions — how many people there you already HOLD, and how many are there
  # that you do not — and those are the two ways into the list, so they are two
  # numbers rather than a total to be split later. Scopes are always the far
  # smaller of the pair, which is the honest shape of it: you hold a handful of
  # people anywhere, and the rest of the country is strangers.
  @countries [
    %{name: "Finland", scopes: 6, unscopes: 122},
    %{name: "Nigeria", scopes: 41, unscopes: 4169},
    %{name: "Brazil", scopes: 18, unscopes: 2652},
    %{name: "Japan", scopes: 9, unscopes: 1831},
    %{name: "Germany", scopes: 14, unscopes: 1506},
    %{name: "Kenya", scopes: 7, unscopes: 973},
    %{name: "India", scopes: 33, unscopes: 6317},
    %{name: "Canada", scopes: 11, unscopes: 1119},
    %{name: "Mexico", scopes: 8, unscopes: 2032},
    %{name: "Egypt", scopes: 5, unscopes: 865},
    %{name: "France", scopes: 12, unscopes: 1378},
    %{name: "Indonesia", scopes: 4, unscopes: 3106},
    %{name: "Sweden", scopes: 9, unscopes: 631},
    %{name: "Philippines", scopes: 15, unscopes: 2265},
    %{name: "Ghana", scopes: 21, unscopes: 699},
    %{name: "Vietnam", scopes: 3, unscopes: 1557},
    %{name: "Poland", scopes: 6, unscopes: 804},
    %{name: "Argentina", scopes: 10, unscopes: 1230}
  ]

  # A LEFT PRESENCE is one someone recorded and left behind, as opposed to the
  # live presence the frame carries. The two are not the same object and must
  # not look alike: a live presence has no duration and no shape, which is why
  # it breathes; a left one is FINISHED, so it has a beginning, an end and a
  # length you can see. Shape is what a recording earns by being over.
  #
  # `from` is here from the start because this row becomes the chat row later —
  # the only difference then is the order they are stacked in. `heard` is the
  # one piece of state a left presence has that a live one cannot: you can miss
  # it, and it should say so.
  @presence_pool [
    %{
      kind: "voice",
      ago: 3,
      len: "0:10",
      from: "them",
      heard: true,
      media: "#{@commons}/9/96/Andy_Mabbett_voice.ogg/Andy_Mabbett_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 18,
      len: "0:37",
      from: "you",
      heard: true,
      media:
        "#{@commons}/8/8e/WIKITONGUES-_Sedang_speaking_Iban.webm/" <>
          "WIKITONGUES-_Sedang_speaking_Iban.webm.360p.vp9.webm"
    },
    %{
      kind: "voice",
      ago: 60,
      len: "0:15",
      from: "them",
      heard: true,
      media: "#{@commons}/b/bb/Bettany_Hughes_voice.ogg/Bettany_Hughes_voice.ogg.mp3"
    },
    %{
      kind: "voice",
      ago: 240,
      len: "0:17",
      from: "you",
      heard: true,
      media: "#{@commons}/0/01/David_Lammy_voice.ogg/David_Lammy_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 540,
      len: "0:46",
      from: "them",
      heard: true,
      media:
        "#{@commons}/2/26/WIKITONGUES-_Tarkhan_speaking_Jek.webm/" <>
          "WIKITONGUES-_Tarkhan_speaking_Jek.webm.360p.vp9.webm"
    },
    %{
      kind: "voice",
      ago: 1440,
      len: "0:16",
      from: "them",
      heard: true,
      media: "#{@commons}/e/ec/David_Harewood_voice.ogg/David_Harewood_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 2880,
      len: "0:54",
      from: "you",
      heard: true,
      media:
        "#{@commons}/e/ea/WIKITONGUES-_Uladzislau_speaking_Belarusian.webm/" <>
          "WIKITONGUES-_Uladzislau_speaking_Belarusian.webm.360p.vp9.webm"
    },
    %{
      kind: "voice",
      ago: 7200,
      len: "0:18",
      from: "them",
      heard: true,
      media: "#{@commons}/0/0f/Alison_Balsom_voice.ogg/Alison_Balsom_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 20160,
      len: "0:48",
      from: "them",
      heard: false,
      media:
        "#{@commons}/c/c9/WIKITONGUES-_Jeries_speaking_Syriac.webm/" <>
          "WIKITONGUES-_Jeries_speaking_Syriac.webm.360p.vp9.webm"
    },
    %{
      kind: "voice",
      ago: 43200,
      len: "0:16",
      from: "you",
      heard: true,
      media: "#{@commons}/f/fa/Brian_Schmidt_voice.ogg/Brian_Schmidt_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 216_000,
      len: "0:56",
      from: "them",
      heard: false,
      media:
        "#{@commons}/2/20/WIKITONGUES-_Yernur_speaking_Kazakh.webm/" <>
          "WIKITONGUES-_Yernur_speaking_Kazakh.webm.360p.vp9.webm"
    },
    %{
      kind: "face",
      ago: 525_600,
      len: "0:58",
      from: "them",
      heard: false,
      media:
        "#{@commons}/0/05/WIKITONGUES-_Rizki_speaking_Malay.webm/" <>
          "WIKITONGUES-_Rizki_speaking_Malay.webm.360p.vp9.webm"
    }
  ]

  @doc "The people you hold, each already carrying the presences they left."
  def scopes do
    @scopes
    |> Enum.with_index()
    |> Enum.map(fn {scope, i} -> Map.put(scope, :presences, presences_for(scope, i)) end)
  end

  @doc "Everyone you have not made a relationship with — the discovery surface."
  def unscopes, do: @unscopes

  @doc "The world, and how many are present in each place right now."
  def countries, do: @countries

  # Newest first, the way a feed reads. `by` is resolved here rather than stored
  # on the pool, because who left a presence depends on whose stream it is
  # appearing in — the same clip is "them" in one and "YOU" in another.
  defp presences_for(user, index) do
    n = length(@presence_pool)

    # A CONVERSATION HAS TWO COLOURS, always maximally apart. Where /presence is
    # a feed of many creators each holding their own hue, a relationship's stream
    # is between exactly two people — you and them — so it reads as two tones
    # rather than a spread. The person's hue comes off their place in the roster
    # by the golden angle, and YOU take its complement, 180 degrees round, so
    # whoever you are talking to your two sides of the exchange never blur into
    # each other.
    person_hue = index |> Kernel.*(137.508) |> round() |> Integer.mod(360)
    you_hue = Integer.mod(person_hue + 180, 360)

    # Rotated so no two people's streams are identical, then SORTED newest first
    # by age — a stream that is not chronological is not a stream. `when` is the
    # age FORMATTED for the eye (3m, 2d, 1y); `ago` is the number it sorts on.
    for k <- 0..5 do
      Enum.at(@presence_pool, rem(index * 4 + k, n))
    end
    |> Enum.sort_by(& &1.ago)
    |> Enum.map(fn presence ->
      presence
      |> Map.put(:by, (presence.from == "you" && "YOU") || user.name)
      |> Map.put(:hue, (presence.from == "you" && you_hue) || person_hue)
      |> Map.put(:when, relative(presence.ago))
      |> Map.put(:rule, rule_width(presence.len))
    end)
  end

  # HOW LONG AGO, in the compact way a feed reads it: the single largest unit
  # that fits, one letter for it. Minutes climb to hours, days, weeks, then
  # months as "mo" so it cannot be mistaken for minutes, and finally years.
  defp relative(min) do
    cond do
      min < 60 -> "#{min}m"
      min < 1_440 -> "#{div(min, 60)}h"
      min < 10_080 -> "#{div(min, 1_440)}d"
      min < 43_200 -> "#{div(min, 10_080)}w"
      min < 525_600 -> "#{div(min, 43_200)}mo"
      true -> "#{div(min, 525_600)}y"
    end
  end

  # HOW LONG, AS A LENGTH. A collapsed presence needs to say more than who left
  # it, but a second line of text would clutter the list and a filled block would
  # read as the captured card and make the screen argue with itself.
  #
  # A rule does neither. It is a line, so it cannot be confused with a
  # rectangle, and its LENGTH is the duration — the same idea as a highlight
  # running short on its last line: you read "this much" without reading a
  # number. Floored well above zero so a ten-second presence is still a mark
  # rather than a speck, and capped so a minute cannot run into the time.
  # Text has no duration, so it gets no rule at all rather than an invented one.
  defp rule_width(nil), do: nil

  defp rule_width(len) do
    [minutes, seconds] = String.split(len, ":")
    secs = String.to_integer(minutes) * 60 + String.to_integer(seconds)
    "#{Float.round(1.5 + min(secs, 60) / 60 * 8.5, 2)}rem"
  end
end
