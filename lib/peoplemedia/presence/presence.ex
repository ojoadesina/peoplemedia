defmodule Peoplemedia.Presence.Presence do
  @moduledoc """
  Whether somebody is here. Nothing else.

  ONE ROW PER PERSON, UPSERTED FOREVER, and that is what makes expiry free:
  `expires_at` in the past means not here, so nothing sweeps, nothing broadcasts,
  and there is no moment at which the app announces that somebody has gone.
  Absence is silent. Two tabs open is one person being here, not two.

  IT USED TO CARRY A MOOD AND A DOING and those have gone to `Rounds`, where they
  belong. Being here is a STATE — automatic, written over, and true or not. Going
  round is an ACT — deliberate, kept, and made again rather than edited. One row
  holding both meant the quiet half could never be simply true and the loud half
  could never accumulate.

  A FRAME DOES NOT ATTACH TO THIS. Presence is the fact of somebody being there;
  a frame is a captured moment, and a moment belongs to the round or the word it
  was captured for.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.People.Person

  schema "presences" do
    belongs_to(:person, Person)
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def changeset(presence, attrs) do
    presence
    |> cast(attrs, [:person_id, :expires_at])
    |> validate_required([:person_id, :expires_at])
  end
end
