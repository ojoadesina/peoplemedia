defmodule Peoplemedia.Directory do
  @moduledoc """
  The people, the places, and the letters between them.

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

  # ── LETTERS ─────────────────────────────────────────────────────────────────
  # A LETTER is what one side leaves for the other, as opposed to the live
  # presence the frame carries. The two are not the same object and must not
  # look alike: a live presence has no duration and no shape, which is why it
  # breathes; a letter is FINISHED, so it has a beginning, an end and a length
  # you can see. Shape is what a recording earns by being over.
  #
  # A LETTER IS WRITTEN TO A SCOPE, NOT TO A PERSON, and that is the whole
  # reason the word changed. "Presence" named the medium — a face, a voice —
  # which made a written one impossible to name at all. A letter names the ACT,
  # and the act is the same whichever of the three it arrives as:
  #
  #   "voice" — you hear them. The mark is the MOUTH, one bar.
  #   "face"  — you see them. The mark is the EYES, two squares.
  #   "text"  — neither. The mark is the mouth STRUCK THROUGH, one bar turned
  #             halfway over: no face here and no voice here, only the words.
  #             A letter is words by default, so this is the plain case and the
  #             other two are what a letter can carry on top of it.
  #
  # `from` says which way it went. `read` is the one piece of state a letter has
  # that a live presence cannot, and it means THE RECIPIENT HAS OPENED IT —
  # so on a letter from them it is "you heard it", and on one of yours it is
  # "they heard it". One field, read from whichever end you are standing at,
  # which is what lets the row say both halves of a conversation at once.
  #
  # THE MEDIA IS REAL for the two recorded kinds; a text letter has none, and
  # no length either, which `rule_width/1` already returns nil for.
  @letter_pool [
    %{
      kind: "voice",
      ago: 3,
      len: "0:10",
      from: "them",
      read: false,
      media: "#{@commons}/9/96/Andy_Mabbett_voice.ogg/Andy_Mabbett_voice.ogg.mp3"
    },
    %{kind: "text", ago: 11, len: nil, from: "them", read: false, media: nil},
    %{
      kind: "face",
      ago: 18,
      len: "0:37",
      from: "you",
      read: true,
      media:
        "#{@commons}/8/8e/WIKITONGUES-_Sedang_speaking_Iban.webm/" <>
          "WIKITONGUES-_Sedang_speaking_Iban.webm.360p.vp9.webm"
    },
    %{kind: "text", ago: 42, len: nil, from: "you", read: false, media: nil},
    %{
      kind: "voice",
      ago: 60,
      len: "0:15",
      from: "them",
      read: true,
      media: "#{@commons}/b/bb/Bettany_Hughes_voice.ogg/Bettany_Hughes_voice.ogg.mp3"
    },
    %{
      kind: "voice",
      ago: 240,
      len: "0:17",
      from: "you",
      read: true,
      media: "#{@commons}/0/01/David_Lammy_voice.ogg/David_Lammy_voice.ogg.mp3"
    },
    %{kind: "text", ago: 320, len: nil, from: "you", read: true, media: nil},
    %{
      kind: "face",
      ago: 540,
      len: "0:46",
      from: "them",
      read: true,
      media:
        "#{@commons}/2/26/WIKITONGUES-_Tarkhan_speaking_Jek.webm/" <>
          "WIKITONGUES-_Tarkhan_speaking_Jek.webm.360p.vp9.webm"
    },
    %{
      kind: "voice",
      ago: 1440,
      len: "0:16",
      from: "them",
      read: true,
      media: "#{@commons}/e/ec/David_Harewood_voice.ogg/David_Harewood_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 2880,
      len: "0:54",
      from: "you",
      read: false,
      media:
        "#{@commons}/e/ea/WIKITONGUES-_Uladzislau_speaking_Belarusian.webm/" <>
          "WIKITONGUES-_Uladzislau_speaking_Belarusian.webm.360p.vp9.webm"
    },
    %{kind: "text", ago: 4320, len: nil, from: "you", read: true, media: nil},
    %{
      kind: "voice",
      ago: 7200,
      len: "0:18",
      from: "them",
      read: true,
      media: "#{@commons}/0/0f/Alison_Balsom_voice.ogg/Alison_Balsom_voice.ogg.mp3"
    },
    %{
      kind: "face",
      ago: 20160,
      len: "0:48",
      from: "them",
      read: false,
      media:
        "#{@commons}/c/c9/WIKITONGUES-_Jeries_speaking_Syriac.webm/" <>
          "WIKITONGUES-_Jeries_speaking_Syriac.webm.360p.vp9.webm"
    },
    %{
      kind: "voice",
      ago: 43200,
      len: "0:16",
      from: "you",
      read: true,
      media: "#{@commons}/f/fa/Brian_Schmidt_voice.ogg/Brian_Schmidt_voice.ogg.mp3"
    },
    %{kind: "text", ago: 100_800, len: nil, from: "you", read: false, media: nil},
    %{
      kind: "face",
      ago: 216_000,
      len: "0:56",
      from: "them",
      read: false,
      media:
        "#{@commons}/2/20/WIKITONGUES-_Yernur_speaking_Kazakh.webm/" <>
          "WIKITONGUES-_Yernur_speaking_Kazakh.webm.360p.vp9.webm"
    },
    %{
      kind: "face",
      ago: 525_600,
      len: "0:58",
      from: "them",
      read: false,
      media:
        "#{@commons}/0/05/WIKITONGUES-_Rizki_speaking_Malay.webm/" <>
          "WIKITONGUES-_Rizki_speaking_Malay.webm.360p.vp9.webm"
    }
  ]

  @doc """
  The people you hold, each carrying its thread of letters and the one-line
  SUMMARY the list row reads.
  """
  def scopes do
    @scopes
    |> Enum.with_index()
    |> Enum.map(fn {scope, i} ->
      letters = letters_for(scope, i)

      scope
      |> Map.put(:letters, letters)
      |> Map.put(:letter, summarise(letters))
    end)
  end

  @doc "Everyone you have not made a relationship with — the discovery surface."
  def unscopes, do: @unscopes

  @doc "The world, and how many are present in each place right now."
  def countries, do: @countries

  # EVERY PLACE AT ONCE, which is what you are looking at before you have chosen
  # one — and, on this surface, what "no country settled in the band" means. It
  # is summed at compile time from the same list the roll is drawn from, so the
  # world can never disagree with the places in it.
  @world %{
    name: "WORLD",
    scopes: Enum.sum(Enum.map(@countries, & &1.scopes)),
    unscopes: Enum.sum(Enum.map(@countries, & &1.unscopes))
  }

  @doc """
  How many of each population a place holds.

  An unknown name answers with the WORLD rather than nil, because the caller is
  a pair of boxes on a live surface: there is no state in which they have
  nothing to show, and "everywhere" is the honest reading of "nowhere in
  particular".
  """
  def population_of("WORLD"), do: @world
  def population_of(name), do: Enum.find(@countries, @world, &(&1.name == name))

  # ── WHAT A ROW SAYS ABOUT A THREAD ──────────────────────────────────────────
  # The list row is not a letter, it is the STATE OF THE CORRESPONDENCE, said in
  # three marks. Everything it shows is derived from the thread rather than
  # stored beside it, so a row can never disagree with the letters it stands for.
  #
  #   THE KIND MARK, on the left, is the LATEST letter's kind — the shape of the
  #   last thing that happened here. It LIGHTS when that letter came from them
  #   and you have not opened it: colour on this surface means "look here", and
  #   an unopened letter is the only thing on a row that is asking for you.
  #   It only ever lights for an incoming letter — lighting the mark on one of
  #   YOUR letters would say you had not read your own.
  #
  #   THE TWO ARROWS, on the right, are the correspondence's two directions,
  #   and each answers a different question:
  #
  #     ↓ INCOMING — has this person ever written? Shown if they have, lit if
  #       their newest letter is still unopened by you, faded once you read it.
  #
  #     ↑ OUTGOING — is the last word yours? Shown ONLY while the newest letter
  #       in the thread is one of yours, lit once they have opened it, faded
  #       while they have not. It EXPIRES the moment they write back, which is
  #       the point of the rule: an arrow still up for a letter you sent last
  #       week would read as a reply that has not landed, when in truth the
  #       conversation has moved on past it.
  #
  # So both arrows showing means "you had the last word and it arrived"; ↓ alone
  # means the ball is theirs to have thrown and yours to catch; neither means
  # nothing has ever passed between you.
  defp summarise([]), do: nil

  defp summarise([latest | _] = letters) do
    %{
      kind: latest.kind,
      when: latest.when,
      unread: latest.from == "them" and not latest.read,
      incoming: opened(Enum.find(letters, &(&1.from == "them"))),
      outgoing: if(latest.from == "you", do: opened(latest))
    }
  end

  # nil means "there is no such letter, so draw no arrow" — which is a different
  # answer from either :read or :unread and must not collapse into them.
  defp opened(nil), do: nil
  defp opened(%{read: true}), do: :read
  defp opened(%{read: false}), do: :unread

  # Newest first, the way a feed reads. `by` is resolved here rather than stored
  # on the pool, because who wrote a letter depends on whose thread it is
  # appearing in — the same clip is "them" in one and "YOU" in another.
  #
  # THE WINDOW LENGTH VARIES WITH THE SCOPE, and that is fixture work rather
  # than design: a fixed six-letter slice of one pool gives every relationship
  # the same shape, and the row summary above has states — never written to,
  # never written back — that a uniform thread can never produce. Two to seven
  # letters, rotated, is enough for all of them to appear somewhere in the list.
  defp letters_for(user, index) do
    n = length(@letter_pool)

    # A CONVERSATION HAS TWO COLOURS, always maximally apart. Where /presence is
    # a feed of many creators each holding their own hue, a relationship's stream
    # is between exactly two people — you and them — so it reads as two tones
    # rather than a spread. The person's hue comes off their place in the roster
    # by the golden angle, and YOU take its complement, 180 degrees round, so
    # whoever you are talking to your two sides of the exchange never blur into
    # each other.
    person_hue = index |> Kernel.*(137.508) |> round() |> Integer.mod(360)
    you_hue = Integer.mod(person_hue + 180, 360)

    # Rotated so no two threads are identical, then SORTED newest first by age —
    # a thread that is not chronological is not a thread. `when` is the age
    # FORMATTED for the eye (3m, 2d, 1y); `ago` is the number it sorts on.
    # EVERY THREAD RUNS ON ITS OWN CLOCK, shifted a few minutes per scope. The
    # pool is one shared timeline, so without this the same newest entry lands
    # at the head of a third of the windows and a third of the list reads "3m" —
    # a column of identical times that says the fixture is one list wearing
    # nineteen names. A constant offset per scope leaves the order inside each
    # thread untouched and only moves where that thread sits in the past.
    skew = index * 11

    for k <- 0..(1 + Integer.mod(index, 6)) do
      Enum.at(@letter_pool, Integer.mod(index * 5 + k, n))
    end
    |> Enum.sort_by(& &1.ago)
    |> Enum.map(fn letter ->
      letter
      |> Map.put(:by, (letter.from == "you" && "YOU") || user.name)
      |> Map.put(:hue, (letter.from == "you" && you_hue) || person_hue)
      |> Map.put(:when, relative(letter.ago + skew))
      |> Map.put(:rule, rule_width(letter.len))
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
