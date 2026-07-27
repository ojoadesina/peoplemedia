defmodule Peoplemedia.Identity.PassportHandle do
  @moduledoc """
  A public nickname for a passport. `handle_code` is normalised (lower-cased) and
  globally unique — it's the lookup key for sign-in and (later) search-by-handle.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Peoplemedia.Identity.Passport

  schema "passport_handles" do
    belongs_to(:passport, Passport)
    field(:handle_code, :string)
    field(:status, :string, default: "active")

    timestamps()
  end

  def changeset(handle, attrs) do
    handle
    |> cast(attrs, [:passport_id, :handle_code, :status])
    |> validate_required([:passport_id, :handle_code])
    |> unique_constraint(:handle_code)
  end
end
