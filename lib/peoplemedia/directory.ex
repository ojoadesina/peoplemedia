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
  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships

  @commons "https://upload.wikimedia.org/wikipedia/commons/transcoded"

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

  # ══ THE LIST ════════════════════════════════════════════════════════════════
  # THE SEAM PROMISED AT THE TOP OF THIS FILE. Scopes and strangers are real
  # rows now — `relationships`, `scopes`, `people` — and these two functions are
  # where the surface stops caring. The SHAPE they return has not changed by a
  # field, which is why nothing above them had to move.
  #
  # LETTERS ARE STILL FIXTURES, and that is the honest state of it: there is no
  # `letters` table yet. Each real scope draws a thread from the pool below by
  # its own id, so the list is populated and the row summary is exercised
  # against real relationships. When the table lands, `letters_for/2` is the
  # only thing that changes.

  @doc """
  The people this person holds, each carrying its thread of letters and the
  one-line SUMMARY the row reads.

  A VISITOR HOLDS NOBODY. Not an error and not an empty page — the surface has
  two lists, and someone without a passport simply has everything in the other
  one. It is also exactly what a new passport looks like on its first morning.
  """
  def scopes(nil), do: []

  def scopes(%Person{id: owner_id}) do
    owner_id
    |> Relationships.held_by()
    |> Enum.map(fn {scope, person} ->
      letters = letters_for(person, thread_seed(person))

      %{
        id: person.id,
        # The LABEL is the owner's word for them; the NAME is their own. The row
        # leads with the first and whispers the second, which is only possible
        # because the two live in different tables.
        label: String.upcase(scope.name),
        name: String.upcase(person.name),
        country: person.country,
        # Presence is not persisted — see the note on `state` above. Until it is
        # live, everyone reads as present rather than as pretend.
        state: "present",
        frame: "empty",
        media: nil,
        letters: letters,
        letter: summarise(letters)
      }
    end)
  end

  @doc """
  Everyone this person has NOT scoped — the discovery surface, and the reason
  strangers are people rows at all. For a visitor that is everybody.
  """
  def unscopes(nil), do: Enum.map(Relationships.everyone(), &stranger/1)

  def unscopes(%Person{id: owner_id}) do
    owner_id |> Relationships.not_held_by() |> Enum.map(&stranger/1)
  end

  # A stranger has no label, because a label is a thing you gave someone, and no
  # letters, because a letter is written to a scope.
  defp stranger(%Person{} = person) do
    %{
      id: person.id,
      label: nil,
      name: String.upcase(person.name),
      country: person.country,
      state: "present",
      frame: "empty",
      media: nil
    }
  end

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

  # WHICH FIXTURE THREAD A PERSON DRAWS, and it has to be stable. Keying this on
  # `scope.id` was wrong in a way that only shows once there is a database: an
  # id is assigned by insertion order, so the same person's letters changed
  # depending on when they happened to be scoped, and no two environments agreed.
  # Hashing the NAME gives the same answer everywhere, forever, and stops being
  # needed at all the day letters are real rows.
  defp thread_seed(%Person{name: name}), do: :erlang.phash2(name, 997)

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
