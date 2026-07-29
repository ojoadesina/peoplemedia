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

  ## OR ON NOBODY AT ALL

  A LETTERHEAD is a letter with an `audience` and no relationship — said out
  loud rather than passed between two people. Exactly one of the two is set,
  which the database enforces as well as this file.

  `read_at` IS MEANINGLESS ON ONE, and deliberately left nil rather than given
  some other reading: it says "the recipient opened it", and a letterhead has as
  many recipients as the audience is wide. Whoever has read one is a table that
  does not exist yet, and inventing an answer in this column would put two
  different meanings in one place.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships.Relationship

  @kinds ~w(voice face text)
  @audiences ~w(relationships world)

  schema "letters" do
    belongs_to(:relationship, Relationship)
    belongs_to(:sender, Person)
    field(:kind, :string, default: "text")
    field(:body, :string)
    field(:media, :string)
    field(:audience, :string)
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

  @doc """
  A letterhead: addressed to an audience, on no relationship.

  A SECOND CHANGESET RATHER THAN A LOOSER FIRST ONE, and the difference matters.
  Relaxing `changeset/2`'s `validate_required([:relationship_id, ...])` enough to
  let a letterhead through would also stop it catching the day `write/3` fails to
  find a relationship and inserts an orphan — one caller's new freedom becoming
  every other caller's missing guard. This one simply never casts
  `relationship_id`, so there is no path from here to a half-addressed letter.
  """
  def broadcast_changeset(letter, attrs) do
    letter
    |> cast(attrs, [:sender_id, :kind, :body, :media, :audience])
    |> validate_required([:sender_id, :kind, :audience])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:audience, @audiences)
    |> validate_body()
    # The database says the same thing, and says it about rows this module never
    # sees. Naming it here is what turns its refusal into a changeset error
    # rather than an exception out of Repo.
    |> check_constraint(:audience,
      name: :letters_have_one_target,
      message: "is addressed to a relationship or to an audience, never both"
    )
  end

  @doc "The audiences a letterhead may be addressed to."
  def audiences, do: @audiences

  defp validate_body(changeset) do
    case get_field(changeset, :kind) do
      "text" ->
        changeset |> validate_required([:body]) |> validate_length(:body, min: 1, max: 4000)

      _ ->
        changeset
    end
  end
end
