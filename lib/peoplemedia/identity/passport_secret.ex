defmodule Peoplemedia.Identity.PassportSecret do
  @moduledoc """
  One word in a passport's bank of one-time secrets. `status` is "active" until a
  successful check-in burns it ("burned"); strength is the active share.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.Identity.Passport

  schema "passport_secrets" do
    belongs_to(:passport, Passport)
    field(:secret_hash, :string)
    field(:order, :integer)
    field(:status, :string, default: "active")
    field(:burned_at, :utc_datetime)

    timestamps()
  end

  def changeset(secret, attrs) do
    secret
    |> cast(attrs, [:passport_id, :secret_hash, :order, :status, :burned_at])
    |> validate_required([:passport_id, :secret_hash, :order])
  end
end
