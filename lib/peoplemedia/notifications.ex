defmodule Peoplemedia.Notifications do
  @moduledoc """
  The notification spine — ONE generic table every feature notifies through, so
  a new kind of news costs a string and not a migration.

  DURABLE ON PURPOSE. A notification waits in the database until it is read, so
  someone who was offline when it happened still finds it. Nothing here rides
  only on a live broadcast, because a PubSub message that arrives at nobody is
  simply gone.

  AND IT ALSO BROADCASTS, which is not a contradiction: the row is the truth and
  the broadcast is a nudge to go and re-read it. Without the nudge a handshake
  answered on one screen sat invisible on the other until somebody reloaded —
  the two people in a two-person act looking at different versions of it. The
  broadcast carries no payload for exactly that reason; a receiver that trusted
  its contents would be trusting a message that may never arrive.

  `notify/4` UPSERTS onto an existing unread row of the same (person, kind,
  actor): scoping the same person twice bumps one notification rather than
  stacking two, which is the difference between a badge that counts events and a
  badge that counts people wanting something from you.
  """
  import Ecto.Query

  alias Peoplemedia.Notifications.Notification
  alias Peoplemedia.Repo

  @doc "Everything happening to one person. Their own surface listens here."
  def topic(person_id), do: "person:#{person_id}"

  def subscribe(person_id),
    do: Phoenix.PubSub.subscribe(Peoplemedia.PubSub, topic(person_id))

  @doc """
  Tell a person's open screens that something about them changed. A nudge, not
  news — see the moduledoc. Safe to call for somebody with nothing open.
  """
  def stir(person_id),
    do: Phoenix.PubSub.broadcast(Peoplemedia.PubSub, topic(person_id), :stir)

  @doc """
  Tell `person_id` that `actor_id` did `kind`. UPSERTS onto an existing UNREAD
  row of the same (person, kind, actor) — a repeated scope request bumps the
  one notification instead of stacking duplicates.
  """
  def notify(person_id, kind, actor_id \\ nil, data \\ %{}) do
    result = do_notify(person_id, kind, actor_id, data)
    stir(person_id)
    result
  end

  defp do_notify(person_id, kind, actor_id, data) do
    # Branch on nil in Elixir, not SQL — a pinned `is_nil(^actor_id)` produced an
    # untyped `$n IS NULL` parameter that Postgres rejects (42P18) at runtime.
    base =
      from(n in Notification,
        where: n.person_id == ^person_id and n.kind == ^kind and is_nil(n.read_at),
        limit: 1
      )

    query =
      if is_nil(actor_id),
        do: where(base, [n], is_nil(n.actor_id)),
        else: where(base, [n], n.actor_id == ^actor_id)

    existing = Repo.one(query)

    case existing do
      nil ->
        %Notification{}
        |> Notification.changeset(%{
          person_id: person_id,
          kind: kind,
          actor_id: actor_id,
          data: data
        })
        |> Repo.insert()

      %Notification{} = n ->
        n |> Notification.changeset(%{data: data}) |> Repo.update()
    end
  end

  @doc "How many unread notifications of the given kinds (a family's badge)."
  def count_kinds(person_id, kinds) when is_list(kinds) do
    Repo.aggregate(
      from(n in Notification,
        where: n.person_id == ^person_id and n.kind in ^kinds and is_nil(n.read_at)
      ),
      :count
    )
  end

  @doc "How many unread notifications a person has (the badge number)."
  def unread_count(person_id) do
    Repo.aggregate(
      from(n in Notification, where: n.person_id == ^person_id and is_nil(n.read_at)),
      :count
    )
  end

  @doc "A person's notifications, newest first."
  def list(person_id, limit \\ 30) do
    Repo.all(
      from(n in Notification,
        where: n.person_id == ^person_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit
      )
    )
  end

  @doc """
  All of a person's notifications of the given kinds, read or not — some kinds
  (a pending join request) ARE the durable truth a panel lists until acted on.
  """
  def of_kind(person_id, kinds) when is_list(kinds) do
    Repo.all(
      from(n in Notification,
        where: n.person_id == ^person_id and n.kind in ^kinds,
        order_by: [desc: n.inserted_at]
      )
    )
  end

  @doc """
  Whether `actor_id` already has a notification of `kind` standing with
  `person_id` whose jsonb data contains `match` — lets a SENDER see their own
  outstanding ask (e.g. a pending place-join) without a parallel table: the
  durable row IS the truth for both sides.
  """
  def standing?(person_id, kind, actor_id, match \\ %{}) do
    Repo.exists?(
      from(n in Notification,
        where: n.person_id == ^person_id and n.kind == ^kind and n.actor_id == ^actor_id,
        where: fragment("? @> ?", n.data, ^match)
      )
    )
  end

  @doc """
  Mark read: everything (`:all`), or only the given `kinds` (a panel clears the
  kinds it displays). Returns the new unread count.
  """
  def mark_read(person_id, :all) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(n in Notification, where: n.person_id == ^person_id and is_nil(n.read_at)),
      set: [read_at: now]
    )

    unread_count(person_id)
  end

  def mark_read(person_id, kinds) when is_list(kinds) do
    now = DateTime.utc_now()

    Repo.update_all(
      from(n in Notification,
        where: n.person_id == ^person_id and n.kind in ^kinds and is_nil(n.read_at)
      ),
      set: [read_at: now]
    )

    unread_count(person_id)
  end

  @doc """
  Remove the notifications a resolved event leaves behind (e.g. a scope pair
  accepting/cancelling clears its request/back rows for BOTH parties).
  """
  def clear(person_id, kinds, actor_id) when is_list(kinds) do
    Repo.delete_all(
      from(n in Notification,
        where: n.person_id == ^person_id and n.kind in ^kinds and n.actor_id == ^actor_id
      )
    )

    :ok
  end
end
