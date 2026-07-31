defmodule Peoplemedia.Relationships do
  @moduledoc """
  Connections between people, expressed as one-sided SCOPES on a shared
  RELATIONSHIP.

  Ported person-for-figure from the project this app grew out of, with the
  spatial half left behind: there are no groups here and no places finer than a
  country, so `zero` (your contract with yourself) and `many` (a group anchored
  to a landmark) did not come across.

  ## THE ASYMMETRY IS THE MODEL

  You scoping Sarah as "MUM" writes YOUR row and nothing of hers. She goes on
  seeing you by your own name until she scopes back, and what she calls you is
  hers to choose. This is why a label cannot live on the relationship, and why
  the list has always drawn a row as a person seen THROUGH a scope.

  ## THE HANDSHAKE, IN THREE ROUNDS

      request_scope   I scope you, and the relationship is `scoping`.
      scope_back      You scope me — your consent, and your own label for me.
      accept          I confirm, and the relationship becomes `scoped`.

  Three rounds rather than two because the second round is not merely a yes: it
  is where you say what you call me, and that is a claim I should see before it
  stands. Both sides hold a label, and neither was handed one.

  ## A DECLINE IS NOT A DEAD END

  `reject/2` does not delete anything. Both sides become `stranger` — a tracked,
  hidden, low-grade tie — and the relationship is marked settled. Nothing is
  lost, the pair can be asked again, and the same row is reopened rather than a
  second one written. Deleting would make "have we ever spoken?" unanswerable.

  ## EVERY WRITE IS IDEMPOTENT

  `(relationship_id, owner_id)` is unique, so asking twice must update rather
  than insert. The reference learned this the hard way — a repeated ask used to
  die on the index and fail silently — and the fix is that each round reports
  what actually happened rather than assuming it was the first.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships.{Relationship, Scope}
  alias Peoplemedia.Repo

  # ── SCOPING ─────────────────────────────────────────────────────────────────
  @doc """
  Owner scopes a target directly: find-or-create the relationship between them,
  then insert the owner's scope. The relationship stays `scoping` until the
  target consents. Returns `{:ok, %{relationship:, scope:}}`.
  """
  def scope_one(%{owner_id: owner_id, target_id: target_id, name: name, type: type} = attrs) do
    Repo.transaction(fn ->
      rel = find_or_create_one(owner_id, target_id)

      case insert_scope(%{
             relationship_id: rel.id,
             owner_id: owner_id,
             target_id: target_id,
             name: name,
             type: type,
             terms: attrs[:terms] || %{}
           }) do
        {:ok, scope} -> %{relationship: rel, scope: scope}
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc "Consent: move a relationship from `scoping` to `scoped`."
  def accept_one(relationship_id) do
    Repo.get(Relationship, relationship_id)
    |> Relationship.changeset(%{state: "scoped"})
    |> Repo.update()
  end

  @doc """
  Round 1 — I scope you. Idempotent: asking again refreshes the label and says
  so rather than dying on the unique index. A pair that declined earlier reopens
  cleanly. Returns `{:ok, :sent | :already_pending | :already_scoped}`.
  """
  def request_scope(owner_id, target_id, name) when owner_id != target_id,
    do: upsert_handshake_scope(owner_id, target_id, name)

  @doc """
  Round 2 — you scope me back. The same idempotent write from the other side;
  the relationship stays `scoping` until round three.
  """
  def scope_back(target_id, initiator_id, name) when target_id != initiator_id,
    do: upsert_handshake_scope(target_id, initiator_id, name)

  defp upsert_handshake_scope(owner_id, target_id, name) do
    Repo.transaction(fn ->
      rel = find_or_create_one(owner_id, target_id)
      mine = Repo.get_by(Scope, relationship_id: rel.id, owner_id: owner_id)

      cond do
        rel.state == "scoped" and mine != nil and mine.type == "related" ->
          :already_scoped

        true ->
          if rel.state != "scoping" do
            {:ok, _} = rel |> Relationship.changeset(%{state: "scoping"}) |> Repo.update()
          end

          case mine do
            nil ->
              case insert_scope(%{
                     relationship_id: rel.id,
                     owner_id: owner_id,
                     target_id: target_id,
                     name: name,
                     type: "related"
                   }) do
                {:ok, _} -> :sent
                {:error, reason} -> Repo.rollback(reason)
              end

            %Scope{type: type} = scope ->
              {:ok, _} =
                scope
                |> Scope.changeset(%{name: name, type: "related", target_id: target_id})
                |> Repo.update()

              # A former stranger reopening counts as a fresh ask, not a repeat.
              if type == "stranger", do: :sent, else: :already_pending
          end
      end
    end)
  end

  @doc "Round 3 — the initiator confirms, and the relationship becomes `scoped`."
  def accept(a_id, b_id) do
    case relationship_between(a_id, b_id) do
      # ONLY A TWO-SIDED CONSENT CAN SEAL. A stranger row left by an earlier
      # decline is not a scope-back, and must not be mistaken for one.
      %Relationship{} = rel ->
        if both_related?(rel.id), do: accept_one(rel.id), else: {:error, :not_ready}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Decline. Both sides become `stranger` and the relationship settles — nothing
  is deleted, the names are kept, and only `type` says what happened.
  """
  def reject(initiator_id, target_id) do
    Repo.transaction(fn ->
      rel = find_or_create_one(initiator_id, target_id)
      make_stranger(rel.id, initiator_id, target_id)
      make_stranger(rel.id, target_id, initiator_id)
      {:ok, _} = accept_one(rel.id)
      :ok
    end)
  end

  @doc """
  Dissolve a standing pair. Both sides become hidden strangers — the same shape
  a decline leaves, so the tie stays tracked and re-askable.
  """
  def unscope(a_id, b_id) do
    case relationship_between(a_id, b_id) do
      %Relationship{} = rel ->
        if both_related?(rel.id) do
          Repo.transaction(fn ->
            make_stranger(rel.id, a_id, b_id)
            make_stranger(rel.id, b_id, a_id)
            {:ok, _} = accept_one(rel.id)
            :unscoped
          end)
        else
          {:error, :not_related}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc "Are these two actually held — a `scoped` relationship with `related` scopes?"
  def related?(a_id, b_id) do
    Repo.exists?(
      from(r in Relationship,
        join: s in Scope,
        on: s.relationship_id == r.id,
        where:
          r.state == "scoped" and s.type == "related" and
            ((s.owner_id == ^a_id and s.target_id == ^b_id) or
               (s.owner_id == ^b_id and s.target_id == ^a_id))
      )
    )
  end

  # ── READING ─────────────────────────────────────────────────────────────────
  @doc "What the VIEWER calls this person — their own label — or nil."
  def scoped_name(viewer_id, target_id) when viewer_id != target_id do
    Repo.one(
      from(s in Scope,
        join: r in Relationship,
        on: s.relationship_id == r.id,
        where: r.state == "scoped" and s.owner_id == ^viewer_id and s.target_id == ^target_id,
        select: s.name,
        limit: 1
      )
    )
  end

  def scoped_name(_viewer_id, _target_id), do: nil

  @doc """
  THE LIST'S OWN QUERY: everyone this person holds, as `{scope, person}` pairs,
  newest first. Only settled, `related` scopes — a pending ask is not yet
  somebody you have, and a stranger row is the record of somebody you decided
  you did not.
  """
  def held_by(owner_id) do
    Repo.all(
      from(s in Scope,
        join: r in Relationship,
        on: s.relationship_id == r.id,
        join: p in Person,
        on: p.id == s.target_id,
        where: r.state == "scoped" and s.type == "related" and s.owner_id == ^owner_id,
        order_by: [desc: s.id],
        select: {s, p}
      )
    )
  end

  @doc """
  Everyone this person does NOT hold. The other half of the list, and the
  reason strangers are people rows: without them this question has no answer.
  Nobody is a stranger to themselves, so the viewer is excluded.
  """
  def not_held_by(owner_id) do
    held =
      from(s in Scope,
        join: r in Relationship,
        on: s.relationship_id == r.id,
        where: r.state == "scoped" and s.type == "related" and s.owner_id == ^owner_id,
        select: s.target_id
      )

    Repo.all(
      from(p in Person,
        where: p.id != ^owner_id and p.id not in subquery(held),
        order_by: [asc: p.id]
      )
    )
  end

  @doc "Everyone, for a visitor with no passport — they hold nobody and are held by nobody."
  def everyone, do: Repo.all(from(p in Person, order_by: [asc: p.id]))

  @doc """
  Who holds THIS person — the other direction of `held_by/1`.

  IT ANSWERS "WHOSE PRIVATE ROUND MAY I SEE". A round made on the Relationships
  tab goes to the people its creator holds, so being able to see one is a fact
  about THEIR scopes, not yours: they scoped you, so you are in their audience.
  Ids only, because the caller is a filter rather than a list.
  """
  def holders_of(nil), do: MapSet.new()

  def holders_of(person_id) do
    Repo.all(
      from(s in Scope,
        join: r in Relationship,
        on: s.relationship_id == r.id,
        where: r.state == "scoped" and s.type == "related" and s.target_id == ^person_id,
        select: s.owner_id
      )
    )
    |> MapSet.new()
  end

  @doc "All of a viewer's own scopes, whatever their state."
  def scopes_owned_by(viewer_id), do: Repo.all(from(s in Scope, where: s.owner_id == ^viewer_id))

  @doc """
  Every handshake still in flight for this person, read from the durable
  `scoping` rows so a reload cannot lose it.

  `%{incoming: [...], outgoing: [...]}`, each entry carrying the other person,
  both labels where they exist, and a `phase`:

      "respond"        they asked; I owe a scope-back
      "waiting_back"   I asked; they have not answered
      "review"         they scoped back; my confirm seals it
      "waiting_accept" I scoped back; their confirm seals it

  The INITIATOR is whoever's scope was written first, which is the earlier id.
  """
  def pending_scopes_for(person_id) do
    rel_ids =
      Repo.all(
        from(s in Scope,
          join: r in Relationship,
          on: r.id == s.relationship_id,
          where: r.state == "scoping" and (s.owner_id == ^person_id or s.target_id == ^person_id),
          select: r.id
        )
      )
      |> Enum.uniq()

    # ONLY `related` SCOPES ARE CONSENT. A stranger row left by a decline would
    # otherwise read as a scope-back and fake a two-sided state.
    scopes =
      Repo.all(
        from(s in Scope,
          where: s.relationship_id in ^rel_ids and s.type == "related",
          order_by: [asc: s.id]
        )
      )

    others =
      scopes
      |> Enum.flat_map(&[&1.owner_id, &1.target_id])
      |> Enum.reject(&(is_nil(&1) or &1 == person_id))
      |> Enum.uniq()

    people =
      Repo.all(from(p in Person, where: p.id in ^others, select: {p.id, p}))
      |> Map.new()

    scopes
    |> Enum.group_by(& &1.relationship_id)
    |> Enum.map(fn {rel_id, ss} ->
      mine = Enum.find(ss, &(&1.owner_id == person_id))
      theirs = Enum.find(ss, &(&1.owner_id != person_id))
      other_id = (mine && mine.target_id) || (theirs && theirs.owner_id)
      initiator? = mine != nil and (theirs == nil or mine.id < theirs.id)

      %{
        rel_id: rel_id,
        other: Map.get(people, other_id),
        my_label: mine && mine.name,
        their_label: theirs && theirs.name,
        phase:
          cond do
            mine != nil and theirs != nil and initiator? -> "review"
            mine != nil and theirs != nil -> "waiting_accept"
            initiator? -> "waiting_back"
            true -> "respond"
          end
      }
    end)
    |> Enum.split_with(&(&1.phase == "respond"))
    |> then(fn {incoming, outgoing} -> %{incoming: incoming, outgoing: outgoing} end)
  end

  # ── PRIVATE ─────────────────────────────────────────────────────────────────
  defp both_related?(rel_id) do
    Repo.aggregate(
      from(s in Scope, where: s.relationship_id == ^rel_id and s.type == "related"),
      :count
    ) >= 2
  end

  # Downgrade this side to `stranger`, or write one named after the person if
  # they never scoped at all. The name is kept; only the type says stranger.
  defp make_stranger(rel_id, owner_id, target_id) do
    case Repo.one(
           from(s in Scope, where: s.relationship_id == ^rel_id and s.owner_id == ^owner_id)
         ) do
      %Scope{} = scope ->
        scope |> Scope.changeset(%{type: "stranger", terms: %{}}) |> Repo.update()

      nil ->
        name = (Repo.get(Person, target_id) || %Person{name: "stranger"}).name

        insert_scope(%{
          relationship_id: rel_id,
          owner_id: owner_id,
          target_id: target_id,
          name: name,
          type: "stranger"
        })
    end
  end

  defp relationship_between(a_id, b_id) do
    Repo.one(
      from(r in Relationship,
        join: s in Scope,
        on: s.relationship_id == r.id,
        where:
          (s.owner_id == ^a_id and s.target_id == ^b_id) or
            (s.owner_id == ^b_id and s.target_id == ^a_id),
        limit: 1,
        select: r
      )
    )
  end

  @doc """
  The row that joins two people, made if it is not there yet.

  A LETTER NEEDS ONE AND A SCOPE IS NOT REQUIRED FOR IT. Writing to somebody
  used to demand a settled scope, which quietly answered a question this app has
  not decided — who may write to whom — and answered it "only people who have
  agreed". That is a rule about permission; this is a row that says two people
  have a correspondence.

  IT MAKES STRANGER SCOPES, and it has to. A `relationships` row carries no
  participants — who it joins is known only through the `scopes` hanging off it
  — so a bare relationship is a row nothing can ever find again, including the
  thread that was written into it. `stranger` is the type this app already uses
  for a tracked tie that grants nothing, and it is the honest word here: you
  have written to each other and that is all.

  CREATING IT GRANTS NOTHING. `related?/2` wants a `scoped` state and two
  `related` scopes; `not_held_by/1` filters on exactly that pair, so somebody
  you have only written to stays in the unscoped list where they belong. And
  `request_scope/3` reads a `stranger` row as a fresh ask, so scoping them later
  is a first ask rather than a repeat.
  """
  def tie(a_id, b_id) when a_id != b_id do
    Repo.transaction(fn ->
      rel = find_or_create_one(a_id, b_id)
      make_stranger(rel.id, a_id, b_id)
      make_stranger(rel.id, b_id, a_id)
      rel
    end)
    |> case do
      {:ok, rel} -> rel
      {:error, _} = err -> err
    end
  end

  defp find_or_create_one(owner_id, target_id) do
    case relationship_between(owner_id, target_id) do
      nil ->
        {:ok, rel} =
          %Relationship{}
          |> Relationship.changeset(%{kind: "one", state: "scoping"})
          |> Repo.insert()

        rel

      %Relationship{} = rel ->
        rel
    end
  end

  defp insert_scope(attrs), do: %Scope{} |> Scope.changeset(attrs) |> Repo.insert()
end
