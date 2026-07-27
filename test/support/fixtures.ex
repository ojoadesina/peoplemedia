defmodule Peoplemedia.Fixtures do
  @moduledoc """
  A cast, for tests that need one.

  The surface used to draw nineteen people out of module attributes, so every
  test of it got a populated list for free. They are rows now, and a test that
  wants a list has to say whose it is — which is the honest cost of the list
  becoming real, and worth paying in one place rather than nineteen.
  """
  alias Peoplemedia.{Identity, People, Relationships}

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

    for {label, name} <- @held do
      them = person(name, "Finland")
      {:ok, _} = Relationships.request_scope(me.id, them.id, label)
      {:ok, _} = Relationships.scope_back(them.id, me.id, "OJO")
      {:ok, _} = Relationships.accept(me.id, them.id)
    end

    for name <- @strangers, do: person(name, "Brazil")

    me
  end

  def held_count, do: length(@held)
  def stranger_count, do: length(@strangers)
end
