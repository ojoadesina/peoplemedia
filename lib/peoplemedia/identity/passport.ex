defmodule Peoplemedia.Identity.Passport do
  @moduledoc """
  A real user's auth/identity record, hanging off their `people` row. Holds the
  hashed 4-digit code and the brute-force guards; the one-time words and the
  nickname(s) live in child tables. Mutated only through `Peoplemedia.Identity`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person
  alias Peoplemedia.Identity.{PassportSecret, PassportHandle}

  schema "passports" do
    belongs_to(:person, Person)
    field(:code_hash, :string)
    field(:strength, :integer, default: 100)
    field(:key_attempts, :integer, default: 0)
    field(:code_attempts, :integer, default: 0)
    field(:locked_until, :utc_datetime)

    has_many(:secrets, PassportSecret)
    has_many(:handles, PassportHandle)

    timestamps()
  end

  def changeset(passport, attrs) do
    passport
    |> cast(attrs, [
      :person_id,
      :code_hash,
      :strength,
      :key_attempts,
      :code_attempts,
      :locked_until
    ])
    |> validate_required([:person_id, :code_hash])
    |> unique_constraint(:person_id)
  end
end
