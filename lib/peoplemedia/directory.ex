defmodule Peoplemedia.Directory do
  @moduledoc """
  The people, the places, and what the list makes of them.

  FIXTURE DATA IS DOWN TO ONE THING NOW: the roll of countries and their
  populations. People, scopes, rounds and words are rows; this file's job is what
  it always said it was — turning them into what a ROW says, which is a different
  question from what any of the tables hold.

  It lives in its own module so a LiveView can be about the SURFACE. That was
  written when everything here was a module attribute, on the promise that "when
  the spine does arrive, this is the one file that changes and every view that
  reads it keeps working". The spine has arrived and the promise held: the views
  above never moved.
  """
  alias Peoplemedia.Clock
  alias Peoplemedia.Presence
  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships
  alias Peoplemedia.Rounds
  alias Peoplemedia.Repo
  alias Peoplemedia.Words

  # WORLD COUNTRIES — the LOCATION list. A scroll of places rather than people;
  # what settles in the band is a country, and its box shows how many are there
  # right now instead of a face or a voice. Finland is the default until another
  # is chosen. The list stays sorted the way the frame reads it — a plain roll of
  # the world, no counts baked into the order.
  #
  # THE ROLL IS FIXTURE, THE NUMBERS ARE NOT. Which places exist is a fact about
  # the world and belongs in a list; how many people are in one is a fact about
  # the rows and is counted from them. Those used to be the same hand-written
  # tuple, which meant Finland claimed 122 strangers while the list under it
  # showed five — the boxes and the list disagreeing about the same question.
  @countries ~w(Finland Nigeria Brazil Japan Germany Kenya India Canada Mexico
                Egypt France Indonesia Sweden Philippines Ghana Vietnam Poland
                Argentina)

  @doc """
  The people this person holds, each carrying what their row says.

  WHAT A ROW SAYS IS A ROUND NOW, not a correspondence. It used to fetch a thread
  of letters per person and boil it down to a one-line summary — a query per name
  to fill a column only one of them is ever read through. A round and its words
  come back for the whole list in one pass, and what is under a name comes back
  when that name is opened; see `page_of/2`.

  A VISITOR HOLDS NOBODY. Not an error and not an empty page — the surface has
  two lists, and someone without a passport simply has everything in the other
  one. It is also exactly what a new passport looks like on its first morning.
  """
  def scopes(nil), do: []

  def scopes(%Person{id: owner_id}) do
    held = Relationships.held_by(owner_id)
    standing = standing_for(Enum.map(held, fn {_scope, person} -> person.id end), owner_id)

    Enum.map(held, fn {scope, person} ->
      %{
        id: person.id,
        # The LABEL is the owner's word for them; the NAME is their own. The row
        # leads with the first and whispers the second, which is only possible
        # because the two live in different tables.
        label: String.upcase(scope.name),
        name: String.upcase(person.name),
        country: person.country
      }
      |> Map.merge(standing[person.id])
    end)
    |> by_round()
  end

  @doc """
  YOU, as the panel reads a person — the subject of your own page.

  IT IS NOT A LIST ROW, which is why it carries less than one: a panel subject
  needs a name, and what goes under it is read when the page opens rather than
  carried on the row — see `page_of/2`.

  `label` IS NIL BECAUSE YOU DO NOT CALL YOURSELF ANYTHING. A label is the word
  you gave somebody, and the header falls back to the name — which is your own.
  """
  def me(nil), do: nil

  def me(%Person{} = person) do
    %{
      id: person.id,
      self: true,
      label: nil,
      name: String.upcase(person.name),
      country: person.country
    }
    # YOUR OWN ROUND READS BACK TO YOU, and it is the only place you can check
    # what you are telling everybody else. It goes through the same filter as
    # theirs, so hiding hides you from yourself too — which is right: the page is
    # showing you what other people see, and what they see is nothing.
    |> Map.merge(standing_for([person.id], person.id)[person.id])
  end

  @doc """
  Everyone this person has NOT scoped — the discovery surface, and the reason
  strangers are people rows at all. For a visitor that is everybody.
  """
  def unscopes(nil) do
    everyone = Relationships.everyone()
    standing = standing_for(Enum.map(everyone, & &1.id), nil)

    everyone |> Enum.map(&stranger(&1, standing)) |> by_round()
  end

  def unscopes(%Person{id: owner_id}) do
    # WHAT IS ALREADY IN FLIGHT WITH EACH OF THEM. "Unscoped" is one word for
    # four different situations — a stranger, somebody you asked and are waiting
    # on, somebody who asked you, and somebody whose answer is sitting there
    # needing your yes — and the row said SCOPE to all four.
    #
    # THAT IS WHERE A DOUBLE SCOPE COMES FROM. The scope room already opens at
    # the true step, so a second ask was refused once you got there; but being
    # OFFERED the act and then told no is worse than never being offered it. The
    # row is where you decide, so the row is where it has to be true.
    #
    # One query for the lot, not one per row — this list is the whole country.
    phases = phases_for(owner_id)
    strangers = Relationships.not_held_by(owner_id)
    standing = standing_for(Enum.map(strangers, & &1.id), owner_id)

    strangers
    |> Enum.map(&Map.put(stranger(&1, standing), :phase, Map.get(phases, &1.id)))
    |> by_round()
  end

  @doc """
  A PERSON'S PAGE: their rounds, newest first, each carrying what was said in it.

  READ WHEN A PAGE OPENS, NOT WITH THE LIST. It is one person's worth of history
  and the list is a country's worth of people — hanging it off every row would be
  a query per name to fill a column only one of them is ever looked at through.
  That is exactly what the thread of letters on every row used to be.

  EXPIRED ROUNDS ARE IN IT and that is the whole point of keeping them: expiry
  stopped a round SURFACING somebody on somebody else's list, which is a different
  question from whether it happened. Law 4.

  WHAT IT DOES NOT DO YET is interleave your rounds with theirs. The guide asks
  for both sides in one place and the page is held until it is properly designed;
  what is here is the half that has an answer — theirs, as they may be seen.
  """
  def page_of(nil, _viewer_id), do: []

  def page_of(person_id, viewer_id) do
    rounds = Rounds.history(person_id, viewer_id)
    words = Words.threads_for(Enum.map(rounds, & &1.id), viewer_id)

    Enum.map(rounds, fn round ->
      Map.merge(round, %{words: Map.get(words, round.id, []), when: Clock.since(round.at)})
    end)
  end

  defp phases_for(owner_id) do
    %{incoming: incoming, outgoing: outgoing} = Relationships.pending_scopes_for(owner_id)

    for e <- incoming ++ outgoing, e.other, into: %{}, do: {e.other.id, e.phase}
  end

  # A stranger has no label, because a label is a thing you gave someone.
  #
  # AND NOTHING ELSE SEPARATES THEM FROM A ROW YOU HOLD. It used to carry five
  # more keys — an empty thread, a null summary, a blank frame — because the row
  # was built out of a correspondence and a stranger has none, and any of them
  # missing crashed whatever opened them. A row is built out of a round now, and
  # a round is something a stranger can perfectly well have gone.
  defp stranger(%Person{} = person, standing) do
    %{
      id: person.id,
      label: nil,
      name: String.upcase(person.name),
      country: person.country
    }
    |> Map.merge(standing[person.id])
  end

  # ── WHETHER THEY ARE HERE, WHAT THEY ARE ROUND WITH, AND WHEN THEY LAST WERE ──
  # THREE QUESTIONS, THREE READS, and they are deliberately not one. Being HERE
  # is a state; going ROUND is an act; when they LAST went is a fact that outlives
  # both. The row used to get all three from one table and the table could only
  # honestly answer the first.
  #
  # `state` IS PRESENCE AND NOTHING ELSE. It stopped being a placeholder when
  # presence became real and it does not now become a placeholder for rounds:
  # somebody with no round is still here, and the surface has always had the
  # vocabulary for that — `data-state`, `is-present`, `is-absent`.
  #
  # `live` IS NOT OURS TO SET. It means a face or a voice actually running, which
  # is ONE thing somebody might be doing inside a round, not what being here IS.
  defp standing_for(ids, viewer_id) do
    here = Presence.live_for(ids)
    # WHO IS LOOKING DECIDES WHAT THEY SEE. A private round goes to the people
    # its creator holds, so the same list is a different list depending on who is
    # reading it — and the viewer has to be carried this far down for that to be
    # true anywhere.
    rounds = Rounds.live_for(ids, viewer_id)
    last = Rounds.last_round_for(ids, viewer_id)

    # WHAT WAS SAID IN THEM. Asked for every live round at once, and only for the
    # live ones: an expired round is off the surface, so its words have nothing
    # to be drawn on.
    words = Words.for_rounds(Enum.map(Map.values(rounds), & &1.id), viewer_id)

    # ONE SELECT FOR THE WHOLE LIST, like every other answer here. The capture is
    # a pair of columns on the person, so it costs a select rather than a join.
    people =
      Person
      |> Repo.all()
      |> Enum.filter(&(&1.id in ids))
      |> Map.new(&{&1.id, &1})

    Map.new(ids, fn id ->
      {id,
       %{
         state: (MapSet.member?(here, id) && "present") || "absent",
         # THE FRAME'S OWN TWO. A capture is a fact about the PERSON, which is why
         # it is read off their row rather than off anything that has passed
         # between you — the frame drew the last letter somebody had sent you
         # once, and went blank for everybody you had never written to.
         capture_kind: people[id] && people[id].capture_kind,
         capture: people[id] && people[id].capture,
         # THE WORDS RIDE WITH THE ROUND THEY ARE IN, so a caller that has one has
         # the other — the item draws them on the same block and would otherwise
         # be reaching into two answers to fill one.
         round: rounds[id] && Map.put(rounds[id], :words, words[rounds[id].id]),
         last_round: last[id]
       }}
    end)
  end

  # ── THE LIST'S ORDER ────────────────────────────────────────────────────────
  # GOING ROUND PULLS YOU TO THE FRONT, and running out leaves you exactly where
  # you were. That second half is the whole rule: an expired round is not demoted,
  # because being overtaken is something SOMEBODY ELSE did and fading is not.
  # Sorting on "is their round live" would drop a person down the list at a moment
  # nobody acted — which is the app moving on their behalf, and it is the same
  # fault as announcing that they had gone.
  #
  # SO IT SORTS ON WHEN THEY LAST WENT, which expiry does not touch. Nobody who
  # has never gone round has an answer, so they hold the order they arrived in,
  # underneath everybody who has.
  defp by_round(rows), do: Enum.sort_by(rows, &round_key/1)

  # Ascending, so `{0, ...}` leads. Anybody who has ever gone round comes first,
  # newest first; anybody who never has holds the order they arrived in
  # underneath — `Enum.sort_by/2` is stable, which is what keeps that true.
  defp round_key(%{last_round: seq}) when is_integer(seq), do: {0, -seq}
  defp round_key(_never), do: {1, 0}

  # A place with nobody in it. Not a missing answer — a real count of zero.
  @none %{scopes: 0, unscopes: 0}

  @doc """
  The world, and how many are in each place — counted for THIS viewer, because
  both numbers are about them: how many people there they hold, and how many
  there they do not.
  """
  def countries(viewer \\ nil) do
    census = census(viewer)

    # THE ROLL IS A STARTING SET, NOT A GUEST LIST. It was a closed list of
    # eighteen while the only way to have a country was to pick one off it.
    # Location detection ended that: somebody's phone can put them in the
    # nineteenth country, and a roll that could not name it would drop them out
    # of the place picker entirely — present in the data, absent from the only
    # control that finds them.
    #
    # SO IT IS THE ROLL PLUS WHEREVER PEOPLE ACTUALLY ARE. The roll leads, in
    # its own order, because it is the world as this app first drew it; the rest
    # follow alphabetically, because there is nothing else to sort them by.
    extra = census |> Map.keys() |> Enum.reject(&(&1 in @countries)) |> Enum.sort()

    Enum.map(@countries ++ extra, &Map.put(Map.get(census, &1, @none), :name, &1))
  end

  # ONE PASS OVER THE PEOPLE, not one query per country. Eighteen places asked
  # separately would be eighteen round trips to draw one scrolling roll, and the
  # roll is drawn on every mount.
  defp census(viewer) do
    held = held_ids(viewer)
    mine = (viewer && viewer.id) || nil

    Person
    |> Repo.all()
    |> Enum.reject(&(&1.id == mine))
    |> Enum.group_by(& &1.country)
    |> Map.new(fn {country, people} ->
      {scoped, strangers} = Enum.split_with(people, &MapSet.member?(held, &1.id))
      {country, %{scopes: length(scoped), unscopes: length(strangers)}}
    end)
  end

  # A VISITOR HOLDS NOBODY, so every count falls entirely on the unscopes side —
  # which is exactly what the list under the box shows them.
  defp held_ids(nil), do: MapSet.new()

  defp held_ids(%Person{id: owner_id}) do
    owner_id |> Relationships.held_by() |> MapSet.new(fn {_scope, person} -> person.id end)
  end

  @doc """
  How many of each population a place holds, for this viewer.

  An unknown name answers with the WORLD rather than nil, because the caller is
  a pair of boxes on a live surface: there is no state in which they have
  nothing to show, and "everywhere" is the honest reading of "nowhere in
  particular". WORLD is the sum of the places, so the two can never disagree.

  A KNOWN PLACE WITH NOBODY IN IT IS NOT AN UNKNOWN PLACE. Both used to come
  back as a nil lookup, so an empty Nigeria answered with the world's totals —
  the box claiming everyone on earth was in a country the list showed as empty.
  Whether the name is on the roll is the question, not whether anyone is there.
  """
  def population_of(viewer \\ nil, name)

  def population_of(viewer, name) do
    census = census(viewer)

    # A PLACE IS SOMEWHERE ON THE ROLL, OR SOMEWHERE SOMEBODY IS. Testing only
    # against the roll made a detected country read as an unknown name and
    # answer with the world's totals — the box claiming everyone on earth was in
    # a country whose list showed four people.
    if name in @countries or Map.has_key?(census, name) do
      census |> Map.get(name, @none) |> Map.put(:name, name)
    else
      census |> Map.values() |> Enum.reduce(@none, &add/2) |> Map.put(:name, "WORLD")
    end
  end

  defp add(%{scopes: a, unscopes: b}, %{scopes: c, unscopes: d}),
    do: %{scopes: a + c, unscopes: b + d}
end
