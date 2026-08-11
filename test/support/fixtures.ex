defmodule Peoplemedia.Fixtures do
  @moduledoc """
  A cast, for tests that need one.

  The surface used to draw nineteen people out of module attributes, so every
  test of it got a populated list for free. They are rows now, and a test that
  wants a list has to say whose it is — which is the honest cost of the list
  becoming real, and worth paying in one place rather than nineteen.
  """
  import Ecto.Query

  alias Peoplemedia.{Identity, People, Presence, Relationships, Rounds, Words}
  alias Peoplemedia.People.Person
  alias Peoplemedia.Repo

  @held [
    {"MUM", "SARAH"},
    {"DAD", "MICHAEL"},
    {"BIG BROTHER", "DANIEL"},
    {"SISTER", "AMAKA"},
    {"GRANDMA", "ROSE"},
    {"COACH", "IBRAHIM"}
  ]

  @strangers ~w(AMINA LEV PRIYA TARKHAN SOPHIE)

  def person(name, country \\ "Finland") do
    {:ok, p} = People.create_person(%{name: name, country: country})
    p
  end

  def passported(name \\ "ojo", words \\ ~w(harbour lantern thistle), code \\ "4417") do
    p = person(name)
    {:ok, _} = Identity.create_passport(p, name, words, code)
    p
  end

  @doc """
  An owner holding six people, with five strangers alongside. The handshake is
  driven all three rounds, because a relationship left at `scoping` is not one
  the list will show — and a fixture that quietly produced the wrong state would
  make every test built on it a lie.
  """
  def cast(owner \\ nil) do
    me = owner || passported()

    # ROUNDS AND WORDS, and deliberately varied. What a row says is drawn from
    # them — the deck's count, its colour, the two flow arrows and whether there
    # is a second block at all — and a cast whose rounds all looked the same
    # would let most of those rot untested.
    #
    #   {is their round still up, what was said in it, in order}
    #
    # A ROUND WITH NOTHING IN IT IS ONE OF THE CASES, not an omission: the item
    # is a single block then, and the joining stroke and the word under it are
    # not drawn at all. So is somebody with no round whatsoever, which is most
    # people most of the time.
    rounds = [
      {:live, ["are you around this evening", "i can do after seven"]},
      {:live, ["just finished the marking"]},
      {:live, []},
      {:expired, ["we should do this again", "next week?"]},
      {:expired, ["morning"]},
      {:none, []}
    ]

    for {{label, name}, {life, words}} <- Enum.zip(@held, rounds) do
      them = person(name, "Finland")
      {:ok, _} = Relationships.request_scope(me.id, them.id, label)
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")
      {:ok, _} = Relationships.accept(me.id, them.id)

      # PRIVATE, SO THE OWNER IS IN THE AUDIENCE. A public round would be seen
      # by everybody and would prove nothing about the read that decides who
      # may — and these are the rows every list test stands on.
      if life != :none do
        {:ok, round} = Rounds.go(them.id, %{"audience" => "private"})

        # BOTH VOICES, ALTERNATING, so `said` and `heard` are each non-zero on a
        # thread long enough to have both — which is the only shape that draws
        # the pair of arrows.
        for {body, i} <- Enum.with_index(words) do
          speaker = (rem(i, 2) == 0 && them) || me
          {:ok, _} = Words.say(round.id, speaker.id, body)
        end

        if life == :expired, do: ran_out(them)
      end
    end

    # STRANGERS WHERE THE OWNER IS. The list is filtered by the place in the box
    # now, so a cast whose strangers all live somewhere else would hand every
    # test an empty unscoped list — and the two questions the surface asks are
    # "who here do I hold" and "who here do I not".
    for name <- @strangers, do: person(name, "Finland")

    # AND NOT EVERYONE IS HERE. Presence is real now, so a cast in which everybody
    # is here would leave `absent` — half of what the row can say — drawn by
    # nothing and asserted by nobody. Three states, all three in the cast: round,
    # here-and-quiet, and gone.
    #
    # SARAH ALREADY WENT ROUND, at the head of the cast — she leads `rounds` and
    # so leads the list. What is missing without this is PRESENCE: going round is
    # an act and being here is a state, and a cast in which the two always
    # coincided would leave half of what a row can say drawn by nothing.
    here(by_name("SARAH"))
    here(by_name("MICHAEL"))
    here(by_name("AMINA"))

    me
  end

  @doc "Somebody who opened the app. Presence, and nothing else."
  def here(%Person{} = person) do
    {:ok, _} = Presence.touch(person.id)
    person
  end

  @doc "Somebody who went round — here on purpose, and saying what it is about."
  def round(%Person{} = person, attrs \\ %{}) do
    {:ok, _} = Presence.touch(person.id)
    {:ok, _} = Rounds.go(person.id, attrs)
    person
  end

  @doc "Send somebody's presence into the past, the way leaving does."
  def gone(%Person{} = person) do
    {:ok, _} = Presence.leave(person.id)
    person
  end

  defp by_name(name), do: Repo.one!(from(p in Person, where: p.name == ^name))

  @doc """
  Run somebody's live round out, the way forty-five quiet minutes do.

  STRAIGHT TO THE ROW, because there is no other way to reach it: `Rounds.stop/1`
  is somebody CHOOSING to stop surfacing, and what the cast needs is the other
  thing — a round nobody ended that simply ran out. They are the same column and
  a different act, and a fixture that used the one for the other would be testing
  a decision where it meant to test a clock.
  """
  def ran_out(%Person{} = person) do
    from(r in Peoplemedia.Rounds.Round, where: r.person_id == ^person.id)
    |> Repo.update_all(set: [expires_at: DateTime.utc_now() |> DateTime.add(-60, :second)])

    person
  end

  def held_count, do: length(@held)
  def stranger_count, do: length(@strangers)
end
