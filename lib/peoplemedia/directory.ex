defmodule Peoplemedia.Directory do
  @moduledoc """
  The people, the places, and what the list makes of them.

  FIXTURE DATA IS DOWN TO ONE THING NOW: the roll of countries and their
  populations. People, scopes and letters are rows; this file's job is what it
  always said it was — turning them into what a ROW says, which is a different
  question from what any of the tables hold.

  It lives in its own module so a LiveView can be about the SURFACE. That was
  written when everything here was a module attribute, on the promise that "when
  the spine does arrive, this is the one file that changes and every view that
  reads it keeps working". The spine has arrived and the promise held: the views
  above never moved.
  """
  alias Peoplemedia.Letters
  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships

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
      letters = Letters.thread_of(scope.relationship_id, owner_id)

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
end
