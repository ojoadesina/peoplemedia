defmodule Peoplemedia.Rounds do
  @moduledoc """
  Going round: surfacing yourself, and saying what it is about.

  IT IS WHAT PRESENCE COULD NOT BE. Being here is a state and it says one thing —
  they have not gone. A round is an ACT: somebody chose to be seen, and chose
  what to be seen doing. That is the difference between a roll of names and a
  reason to say something, and it is what "so you don't do life alone" actually
  rests on.

  ## MADE, NOT EDITED

  Every round is its own row and none of them is ever written over. Going round
  again is a new one; the old one keeps its words, its age and its place in the
  history. That is Law 4 — expiry is about VISIBILITY, never deletion — and it is
  what lets a person's page list what they have been up to.

  ## IT DIES QUIETLY, AND ONLY HALFWAY

  Forty-five minutes after the CREATOR goes quiet, not the last person to speak:
  a round is somebody surfacing themselves, so it lasts as long as they are still
  the one there. `expires_at` in the past means the row stops SURFACING them —
  the name and the boxes leave — and nothing else changes. The words go on. The
  notifications go on. Nobody is told it happened, because absence is silent.

  ## WHO IT IS FOR IS NOT A QUESTION ANYBODY IS ASKED

  Public is everyone. Private is the people you hold, or one of them when a
  target is set. The tab you were standing on decides which, so the audience is
  read off the surface rather than chosen from a control.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.People.Person
  alias Peoplemedia.Relationships
  alias Peoplemedia.Repo
  alias Peoplemedia.Rounds.Round

  # HOW LONG A ROUND SURFACES SOMEBODY PAST THEIR LAST CONTACT.
  #
  # FIXED, NOT MEASURED, and the reason is not that an algorithm would be wrong.
  # A person has to be able to answer "why am I still showing?", and "we measured
  # how long you spent in the app" is not an answer that can go on a screen.
  @minutes 45

  @doc """
  Go round. A person, and whatever they chose to say about it.

  ALL OF IT OPTIONAL. A round with nothing on it is "I am here and open to being
  joined", which is the smallest true thing anybody can say here — refusing it
  would make the quietest version of the act unreachable.
  """
  def go(person_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), blank_to_nil(v)} end)
      |> Map.put_new("audience", "public")
      |> Map.merge(%{
        "person_id" => person_id,
        "expires_at" => horizon(),
        "number" => next_number(person_id)
      })

    %Round{} |> Round.changeset(attrs) |> Repo.insert()
  end

  # THEIR NEXT ONE. Counted off the highest number they have rather than off how
  # many rows exist, so nothing before it can shift the answer — and a unique
  # index on the pair means a race loses loudly rather than quietly handing two
  # rounds the same number.
  defp next_number(person_id) do
    Repo.one(from(r in Round, where: r.person_id == ^person_id, select: max(r.number)))
    |> then(&((&1 || 0) + 1))
  end

  @doc """
  Still here. Pushes the live round's horizon out — the creator going on using
  the app is exactly what keeps it up.

  IT DOES NOT REVIVE AN EXPIRED ONE. A round that has run out does not come back;
  going round again is a new row and one tap. So this only ever reaches something
  still live, and coming back after an hour surfaces nothing until you choose to.
  """
  def keep(person_id) do
    at = now()

    {n, _} =
      Repo.update_all(
        from(r in Round, where: r.person_id == ^person_id and r.expires_at > ^at),
        set: [expires_at: horizon(), updated_at: naive_now()]
      )

    n
  end

  @doc "Stop surfacing now. Not a delete — the round keeps everything it holds."
  def stop(person_id) do
    at = now()

    {n, _} =
      Repo.update_all(
        from(r in Round, where: r.person_id == ^person_id and r.expires_at > ^at),
        set: [expires_at: at, updated_at: naive_now()]
      )

    n
  end

  @doc "This person's live round, or nil. At most one is live at a time."
  def live(nil), do: nil

  def live(person_id) do
    # READ AS THEMSELVES. Your own round is always yours to see, whoever it is
    # for — this is the call `Directory.me/1` makes for your own page.
    person_id |> List.wrap() |> live_for(person_id) |> Map.get(person_id)
  end

  @doc """
  Everyone still round, out of the given ids — `%{person_id => round}`.

  ONE QUERY FOR THE WHOLE LIST, not one per row. The list is a country's worth of
  people and it is redrawn on every mount.

  THE NEWEST WINS. Nothing stops two live rounds existing — `go/2` does not close
  the last one, because closing it would be the app deciding that going round
  again retracts what you said before. So the read picks the newest and the older
  one simply stops surfacing, which is the same thing expiry does.

  HIDING IS APPLIED HERE, in the join, precisely so that a caller cannot forget
  it: there is no path from a hidden person to a surface because there is no
  other way in.
  """
  def live_for(person_ids, viewer_id \\ nil)

  def live_for([], _viewer_id), do: %{}

  def live_for(person_ids, viewer_id) do
    at = now()
    # WHO HAS SCOPED THE VIEWER. A private round with no target goes to the
    # people its creator holds, so whether you may see one is a fact about THEIR
    # scopes: they scoped you, so you are in the audience. One small query rather
    # than a correlated subquery per row.
    holders = viewer_id |> Relationships.holders_of() |> MapSet.to_list()

    Repo.all(
      from(r in Round,
        join: p in Person,
        on: p.id == r.person_id,
        where: r.person_id in ^person_ids and r.expires_at > ^at and p.around_hidden == false,
        # ── WHO MAY SEE IT ────────────────────────────────────────────────────
        # THIS WAS MISSING ENTIRELY, and the surface was the wrong place to
        # notice: a private round rendered exactly like a public one, so it
        # looked correct while being shown to strangers. Audience is a fact
        # about the ROW and it belongs in the read, where no caller can skip it.
        where:
          r.audience == "public" or
            r.person_id == ^to_id(viewer_id) or
            r.target_id == ^to_id(viewer_id) or
            (r.audience == "private" and is_nil(r.target_id) and r.person_id in ^holders),
        order_by: [asc: r.person_id, desc: r.inserted_at, desc: r.id],
        distinct: r.person_id,
        select: r
      )
    )
    |> Map.new(&{&1.person_id, read(&1)})
  end

  # A VISITOR HAS NO ID, and comparing a column to nil in SQL is never true —
  # which is the honest answer here: somebody with no passport is in nobody's
  # private audience and is not the target of anything. -1 makes that explicit
  # rather than relying on nil's behaviour in a pinned comparison.
  defp to_id(nil), do: -1
  defp to_id(id), do: id

  @doc """
  How recently each of these people last went round — `%{person_id => round id}`.

  THE LIST SORTS BY THIS AND EXPIRY DOES NOT TOUCH IT. Going round pulls you to
  the front; running out leaves you exactly where you were, until somebody else
  goes round and overtakes you. So the question is "when did they last go", not
  "are they going now", and an expired round answers it as well as a live one.

  AN ID RATHER THAN A TIME, and that is not an optimisation. `timestamps()` here
  is second-precision, so two rounds made in the same second compare EQUAL — and
  a tie sends the sort back to whatever order the list was already in, which is
  the list rearranging itself for reasons nobody can see. The id is monotonic and
  cannot tie. Nothing reads this as a date; it exists to be compared.
  """
  def last_round_for(person_ids, viewer_id \\ nil)

  def last_round_for([], _viewer_id), do: %{}

  def last_round_for(person_ids, viewer_id) do
    # THE ORDER IS A READ LIKE ANY OTHER, and forgetting that leaked exactly what
    # hiding the row's text had just stopped leaking: a private round pulled its
    # creator to the top of a STRANGER'S list. They could not see what it said
    # and did not need to — being at the front is the claim, and the claim was
    # visible. Position is content.
    holders = viewer_id |> Relationships.holders_of() |> MapSet.to_list()
    me = to_id(viewer_id)

    Repo.all(
      from(r in Round,
        where: r.person_id in ^person_ids,
        where:
          r.audience == "public" or r.person_id == ^me or r.target_id == ^me or
            (r.audience == "private" and is_nil(r.target_id) and r.person_id in ^holders),
        group_by: r.person_id,
        select: {r.person_id, max(r.id)}
      )
    )
    |> Map.new()
  end

  @doc """
  Everything this person has ever gone round with, newest first — their page.

  EXPIRED ONES COME BACK IN THIS LIST and that is the whole point of keeping
  them: expiry stopped them SURFACING the person on somebody else's list, which
  is a different question from whether they happened.
  """
  def history(person_id, limit \\ 30) do
    Repo.all(
      from(r in Round,
        where: r.person_id == ^person_id,
        order_by: [desc: r.inserted_at, desc: r.id],
        limit: ^limit
      )
    )
    |> Enum.map(&read/1)
  end

  @doc "One round by id, read the way a surface wants it, or nil."
  def get(id) do
    case Repo.get(Round, id) do
      nil -> nil
      round -> read(round)
    end
  end

  @doc "How long a round surfaces somebody past their last contact, in minutes."
  def minutes, do: @minutes

  def audiences, do: Round.audiences()

  # WHAT A SURFACE IS HANDED. The row's own keys plus the one thing every caller
  # would otherwise work out for itself — whether it is still up. Derived, because
  # a column for it would let a row disagree with the clock.
  defp read(%Round{} = r) do
    %{
      id: r.id,
      number: r.number,
      person_id: r.person_id,
      target_id: r.target_id,
      audience: r.audience,
      # A ROUND BETWEEN TWO PEOPLE IS A DIFFERENT KIND OF THING from one going
      # out to everybody you hold, and the row marks it. Derived, because it is
      # simply what having a target MEANS.
      direct: not is_nil(r.target_id),
      expires_at: r.expires_at,
      at: r.inserted_at,
      live: DateTime.compare(r.expires_at, DateTime.utc_now()) == :gt
    }
  end

  # A FIELD SOMEBODY CLEARED IS A FIELD WITH NOTHING IN IT. A form sends empty
  # strings for untouched controls, and everything on a round is optional — so an
  # empty one has to arrive as absent rather than as a blank somebody typed.
  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp naive_now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  defp horizon,
    do: DateTime.utc_now() |> DateTime.add(@minutes * 60, :second) |> DateTime.truncate(:second)
end
