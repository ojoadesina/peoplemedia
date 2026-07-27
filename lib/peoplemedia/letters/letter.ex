defmodule Peoplemedia.Letters.Letter do
  @moduledoc """
  One letter on a relationship.

  IT IS THE ACT, NOT THE MEDIUM. `kind` says what it arrived as — a voice, a
  face, or only words — and all three are letters. That is the whole reason the
  word changed from "presence": "record" named the capturing, which words never
  went through.

  `sender_id` is which of the two wrote it, and `read_at` means the RECIPIENT
  opened it. Both are single columns on a shared row rather than a field per
  side, so the two people can never end up holding different versions of the
  same correspondence.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships.Relationship

  @kinds ~w(voice face text)

  schema "letters" do
    belongs_to(:relationship, Relationship)
    belongs_to(:sender, Person)
    field(:kind, :string, default: "text")
    field(:body, :string)
    field(:media, :string)
    field(:read_at, :utc_datetime)

    timestamps()
  end

  def changeset(letter, attrs) do
    letter
    |> cast(attrs, [:relationship_id, :sender_id, :kind, :body, :media, :read_at])
    |> validate_required([:relationship_id, :sender_id, :kind])
    |> validate_inclusion(:kind, @kinds)
    # A TEXT LETTER WITH NO WORDS IS NOT A LETTER. The other two carry their
    # meaning in the media, so they are allowed an empty body.
    |> validate_body()
  end

  defp validate_body(changeset) do
    case get_field(changeset, :kind) do
      "text" ->
        changeset |> validate_required([:body]) |> validate_length(:body, min: 1, max: 4000)

      _ ->
        changeset
    end
  end
end
