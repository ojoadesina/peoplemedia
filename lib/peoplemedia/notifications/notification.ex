defmodule Peoplemedia.Notifications.Notification do
  @moduledoc """
  One notification: `person_id` (the recipient) is told that `actor_id` did
  `kind`, with whatever `data` the kind needs (labels, names…). `read_at` nil =
  unread (counts toward the badge). Generic on purpose — any feature can write
  its own kinds without schema changes (the Laravel notifications shape).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field(:person_id, :integer)
    field(:kind, :string)
    field(:actor_id, :integer)
    field(:data, :map, default: %{})
    field(:read_at, :utc_datetime_usec)

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:person_id, :kind, :actor_id, :data, :read_at])
    |> validate_required([:person_id, :kind])
  end
end
