defmodule Peoplemedia.Letters do
  @moduledoc """
  What has passed between two people.

  A letter hangs off the RELATIONSHIP, because a correspondence is shared and a
  scope is not — mine says "MUM", hers says something else, and a thread hung off
  either would be a thread only one of us could see.

  ## OR OFF AN AUDIENCE, AND NEVER BOTH

  A LETTERHEAD is the other kind: written to a population rather than to a
  person, with nobody in particular to answer it. It carries an `audience` and
  no relationship, which is why nothing here had to learn a new shape — a thread
  query asks for one relationship id, and NULL is not one.

  The two are one table because they are one thing said two ways, and the day a
  letterhead grows replies the reply will be a letter like any other.

  ## THE THREAD READS FROM WHERE YOU STAND

  The rows are the same for both people; what differs is the reading. `from` is
  "you" when you sent it and "them" when you did not, and `read` means the
  RECIPIENT opened it — so on a letter of theirs it says you heard it, and on one
  of yours it says they did. One row, two readings, and no way for the two sides
  to hold different versions of the same conversation.

  The shape it returns is the one `Directory` has been handing the surface since
  the letters were fixtures, so nothing above had to move when they became rows.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.Letters.Letter
  alias Peoplemedia.Relationships
  alias Peoplemedia.Relationships.{Relationship, Scope}
  alias Peoplemedia.Repo

  @doc """
  The thread between two people, newest first, read from `viewer`'s side.
  Returns `[]` when they have no relationship — which is not an empty
  conversation but the absence of one.
  """
  def thread(viewer_id, other_id) do
    case relationship_id(viewer_id, other_id) do
      nil -> []
      rel_id -> rel_id |> rows() |> Enum.map(&read_from(&1, viewer_id))
    end
  end

  @doc "The same thread when the relationship is already known."
  def thread_of(rel_id, viewer_id) when is_integer(rel_id),
    do: rel_id |> rows() |> Enum.map(&read_from(&1, viewer_id))

  # THE SENDER COMES WITH THE ROW. The panel names whoever left each letter, and
  # a thread that had to be handed the other person's name separately would be
  # one more thing for a caller to get wrong.
  defp rows(rel_id) do
    Repo.all(
      from(l in Letter,
        where: l.relationship_id == ^rel_id,
        order_by: [desc: l.inserted_at, desc: l.id],
        preload: [:sender]
      )
    )
  end

  @doc """
  Write one, opening the tie if there is not one yet.

  IT USED TO REFUSE ANYONE YOU HAD NOT SCOPED, on the reasoning that being able
  to write is the point of scoping. That is a rule about PERMISSION — who may
  write to whom — and this app has not decided it; refusing here decided it by
  accident, and decided it "never". A letter now makes the row it needs. The row
  grants nothing on its own: `Relationships.related?/2` still wants a settled
  state and two agreed scopes, so a letter does not make anybody scoped.
  """
  def write(sender_id, recipient_id, attrs) do
    case relationship_id(sender_id, recipient_id) ||
           tie_id(sender_id, recipient_id) do
      nil ->
        {:error, :no_relationship}

      rel_id ->
        %Letter{}
        |> Letter.changeset(Map.merge(attrs, %{relationship_id: rel_id, sender_id: sender_id}))
        |> Repo.insert()
    end
  end

  @doc """
  Say one out loud — a LETTERHEAD, addressed to an audience rather than to
  anybody.

  NO TIE IS OPENED, and that is the difference from `write/3` rather than an
  omission. A tie is a row saying these two people have spoken; a letterhead is
  not spoken to anyone, so there is nobody for it to be a row about.
  """
  def broadcast(sender_id, audience, attrs) do
    %Letter{}
    |> Letter.broadcast_changeset(Map.merge(attrs, %{sender_id: sender_id, audience: audience}))
    |> Repo.insert()
  end

  @doc """
  Everything this person has said out loud, newest first, read from their own
  side — the self page's list.

  `read` IS ALWAYS FALSE ON THESE AND MUST NOT BE READ. The field means the
  RECIPIENT opened it, and a letterhead has as many recipients as its audience
  is wide; who has read one is a table that does not exist yet. It is here at all
  only because these share the reading the panel has always been handed, and a
  shape that dropped a key would be a shape the panel has to branch on.
  """
  def broadcasts_by(sender_id, limit \\ 30) do
    Repo.all(
      from(l in Letter,
        where: l.sender_id == ^sender_id and not is_nil(l.audience),
        order_by: [desc: l.inserted_at, desc: l.id],
        limit: ^limit,
        preload: [:sender]
      )
    )
    |> Enum.map(&read_from(&1, sender_id))
  end

  @doc """
  Mark everything the viewer did NOT send as read. Called when a thread is
  opened, because opening it IS the reading — asking someone to press a second
  thing to admit they read it would be asking them to do the app's bookkeeping.
  """
  def mark_read(viewer_id, other_id) do
    case relationship_id(viewer_id, other_id) do
      nil ->
        0

      rel_id ->
        {n, _} =
          Repo.update_all(
            from(l in Letter,
              where:
                l.relationship_id == ^rel_id and l.sender_id != ^viewer_id and is_nil(l.read_at)
            ),
            set: [read_at: DateTime.utc_now() |> DateTime.truncate(:second)]
          )

        n
    end
  end

  # THE VIEWER'S READING of a shared row. `from`, `read` and `when` are what the
  # row summary and the panel have always been handed; `len` and `media` come
  # straight off the row.
  defp read_from(%Letter{} = l, viewer_id) do
    %{
      id: l.id,
      kind: l.kind,
      body: l.body,
      media: l.media,
      from: (l.sender_id == viewer_id && "you") || "them",
      # WHO LEFT IT, as the panel says it: your own letters are "YOU" rather
      # than your name, because a thread read from your side is a conversation
      # and not a transcript.
      by: (l.sender_id == viewer_id && "YOU") || String.upcase(l.sender.name),
      read: not is_nil(l.read_at),
      ago: minutes_since(l.inserted_at),
      when: relative(minutes_since(l.inserted_at))
    }
  end

  defp minutes_since(at) do
    at
    |> DateTime.from_naive!("Etc/UTC")
    |> then(&DateTime.diff(DateTime.utc_now(), &1, :second))
    |> div(60)
    |> max(0)
  end

  # HOW LONG AGO, in the compact way a feed reads it: the single largest unit
  # that fits, one letter for it. Months are "mo" so they cannot be mistaken for
  # minutes. Moved here from Directory with the letters it describes.
  defp relative(min) do
    cond do
      min < 60 -> "#{min}m"
      min < 1_440 -> "#{div(min, 60)}h"
      min < 10_080 -> "#{div(min, 1_440)}d"
      min < 43_200 -> "#{div(min, 10_080)}w"
      min < 525_600 -> "#{div(min, 43_200)}mo"
      true -> "#{div(min, 525_600)}y"
    end
  end

  # Writing to yourself is the one case with no tie to make.
  defp tie_id(a_id, b_id) when a_id == b_id, do: nil

  defp tie_id(a_id, b_id) do
    case Relationships.tie(a_id, b_id) do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp relationship_id(a_id, b_id) do
    Repo.one(
      from(r in Relationship,
        join: s in Scope,
        on: s.relationship_id == r.id,
        where:
          (s.owner_id == ^a_id and s.target_id == ^b_id) or
            (s.owner_id == ^b_id and s.target_id == ^a_id),
        limit: 1,
        select: r.id
      )
    )
  end
end
