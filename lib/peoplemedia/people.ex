defmodule Peoplemedia.People do
  @moduledoc """
  The people. Everyone the app knows about, held or not.

  This is deliberately thin. Reading people for the LIST is `Peoplemedia.Directory`'s
  job, because a list row is a person seen THROUGH a scope — with the label you
  gave them and the letters between you — and that is a different question from
  "who is this". This context answers the second one.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.People.Person
  alias Peoplemedia.Repo

  @doc "One person by id, or nil."
  def get_person(nil), do: nil
  def get_person(id), do: Repo.get(Person, id)

  @doc "One person by id, raising if they are not there."
  def get_person!(id), do: Repo.get!(Person, id)

  @doc "Put a person into the world. Everyone starts here — with or without a passport."
  def create_person(attrs) do
    %Person{} |> Person.changeset(attrs) |> Repo.insert()
  end

  def change_person(%Person{} = person, attrs \\ %{}), do: Person.changeset(person, attrs)
end
