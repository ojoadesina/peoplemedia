defmodule Peoplemedia.Fixtures do
  @moduledoc """
  A cast, for tests that need one.

  The surface used to draw nineteen people out of module attributes, so every
  test of it got a populated list for free. They are rows now, and a test that
  wants a list has to say whose it is — which is the honest cost of the list
  becoming real, and worth paying in one place rather than nineteen.
  """
  import Ecto.Query

  alias Peoplemedia.{Identity, Letters, People, Presence, Relationships, Rounds}
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

    # LETTERS TOO, and deliberately varied. The row summary has four arrow
    # states and a lit mark, and a cast whose threads all look the same would
    # let three of them rot untested.
    #
    # ALL THREE KINDS TOO. The row's mark is drawn from the newest letter's
    # kind, so a cast written entirely in text would leave the eyes and the
    # mouth undrawn and their tests passing on nothing.
    #
    #   {who wrote it, whether the recipient opened it, what it arrived as}
    threads = [
      [{:them, false, "voice"}],
      [{:you, true, "face"}],
      [{:them, true, "text"}, {:you, true, "voice"}],
      [{:you, false, "text"}, {:them, true, "face"}],
      [{:them, false, "face"}, {:you, true, "text"}],
      []
    ]

    for {{label, name}, thread} <- Enum.zip(@held, threads) do
      them = person(name, "Finland")
      {:ok, _} = Relationships.request_scope(me.id, them.id, label)
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")
      {:ok, _} = Relationships.accept(me.id, them.id)

      # Oldest first, so the last one written is the newest — which is the one
      # the row summary speaks for.
      for {who, read, kind} <- Enum.reverse(thread) do
        sender = (who == :you && me) || them
        recipient = (who == :you && them) || me

        attrs =
          case kind do
            "text" -> %{kind: "text", body: "hello"}
            other -> %{kind: other, media: "https://example.test/#{other}.mp3"}
          end

        {:ok, letter} = Letters.write(sender.id, recipient.id, attrs)
        if read, do: mark_read(letter)
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
    # SARAH IS THE ONE WHO WENT ROUND, and she is the only one, because the boxes
    # beside the band show one person at a time and a test that finds a mood
    # needs to know whose it is.
    round(by_name("SARAH"), %{
      name: "the witchers, finally",
      mood: "happy",
      activity: "movie",
      about: "the witchers"
    })

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

  # Straight to the row, because `Letters.mark_read/2` marks a whole side of a
  # thread and these need one letter at a time.
  defp mark_read(letter) do
    letter
    |> Ecto.Changeset.change(read_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update!()
  end

  def held_count, do: length(@held)
  def stranger_count, do: length(@strangers)
end
