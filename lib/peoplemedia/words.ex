defmodule Peoplemedia.Words do
  @moduledoc """
  Words inside rounds.

  TWO QUESTIONS, ASKED FOR A WHOLE LIST AT A TIME. What is the last thing said in
  this round, and how many things are in it — the two the surface draws. Both are
  answered in one pass over the ids, the way every other list-shaped answer in
  this app is, because the alternative is one query per item on a column that is
  redrawn on every stir.
  """
  import Ecto.Query, warn: false

  alias Peoplemedia.Clock
  alias Peoplemedia.Repo
  alias Peoplemedia.Words.{Read, Word}

  def say(round_id, person_id, body, opts \\ []) do
    %Word{}
    |> Word.changeset(%{
      round_id: round_id,
      person_id: person_id,
      body: body,
      reply_to_id: opts[:reply_to_id],
      images: opts[:images] || []
    })
    |> Repo.insert()
  end

  @doc """
  `%{round_id => %{count, last, said, heard}}` for the rounds asked about.

  `said` AND `heard` ARE THE TWO DIRECTIONS, counted rather than flagged, and
  that is what the arrows on an item are drawn from: whether anything of yours is
  in there, and whether anything of anybody else's is. A round you have spoken in
  and a round you have only watched are different things to come back to.

  NOBODY ASKED ABOUT IS NOBODY QUERIED — an empty list must not become a query
  for every word in the table.
  """
  def for_rounds([], _viewer_id), do: %{}

  def for_rounds(round_ids, viewer_id) do
    # HOW FAR THIS READER HAS GOT IN EACH OF THEM, in one query beside the words
    # themselves. A visitor has no marks and therefore no seen words, which is
    # correct rather than a special case: they have not seen any.
    seen =
      Read
      |> where([r], r.round_id in ^round_ids and r.person_id == ^(viewer_id || -1))
      |> Repo.all()
      |> Map.new(&{&1.round_id, &1.seen_id})

    Word
    |> where([w], w.round_id in ^round_ids)
    |> order_by([w], asc: w.id)
    |> Repo.all()
    |> Enum.group_by(& &1.round_id)
    |> Map.new(fn {round_id, words} ->
      {round_id,
       %{
         count: length(words),
         last: List.last(words).body,
         # HOW MANY PICTURES ARE IN THERE, over the whole round rather than on the
         # last word alone: the item's stack says "there are pictures in this
         # round", which is a fact about the round the way the count is.
         images: Enum.sum(Enum.map(words, &length(&1.images))),
         said: Enum.count(words, &(&1.person_id == viewer_id)),
         heard: Enum.count(words, &(&1.person_id != viewer_id)),
         # WHAT IS STILL WAITING FOR THIS READER. No mark means none seen, which
         # is the resting state — so a round you have never opened is entirely
         # unseen, which is exactly what it is.
         unseen: Enum.count(words, &(&1.id > Map.get(seen, round_id, 0)))
       }}
    end)
  end

  @doc """
  MARK A ROUND SEEN, UP TO ITS NEWEST WORD.

  LOOKING AT IT IS READING IT. Asking for a second press to admit you have seen
  something is asking you to do the app's bookkeeping — the same rule the letters
  this replaces were opened under.

  IT ONLY EVER MOVES FORWARD. `seen_id` takes the greater of what is there and
  what has arrived, so a stale patch or a second reader's race cannot walk it
  backwards and re-light a round somebody has already read.
  """
  def see(nil, _round_id), do: :nobody
  def see(_person_id, nil), do: :no_round

  def see(person_id, round_id) do
    newest =
      Word
      |> where([w], w.round_id == ^round_id)
      |> select([w], max(w.id))
      |> Repo.one()

    case newest do
      nil ->
        :nothing_said

      id ->
        %Read{}
        |> Read.changeset(%{person_id: person_id, round_id: round_id, seen_id: id})
        |> Repo.insert(
          on_conflict: [set: [seen_id: id, updated_at: NaiveDateTime.utc_now(:second)]],
          conflict_target: [:person_id, :round_id]
        )
    end
  end

  @doc """
  Every word in these rounds, oldest first, read from where the viewer stands —
  `%{round_id => [word]}`.

  ONE QUERY FOR A WHOLE PAGE, like every other list-shaped answer in this app. A
  person's page is a stack of rounds and asking each of them separately would be
  one round trip per block on a column that is redrawn every time a panel opens.

  OLDEST FIRST, WHICH IS THE OPPOSITE OF THE PAGE'S OWN ORDER, and deliberately:
  the rounds run newest-first because the last thing somebody did is what you
  came for, and the words inside one run in the order they were said because that
  is the only order a conversation can be read in.
  """
  def threads_for([], _viewer_id), do: %{}

  def threads_for(round_ids, viewer_id) do
    Word
    |> where([w], w.round_id in ^round_ids)
    |> order_by([w], asc: w.id)
    # WHO SAID IT COMES WITH THE ROW. The page names whoever left each word, and
    # a thread that had to be handed the other person's name separately would be
    # one more thing for a caller to get wrong.
    |> preload(:person)
    |> Repo.all()
    |> Enum.group_by(& &1.round_id, &read_from(&1, viewer_id))
  end

  @doc "Every word in one round, oldest first, read from where the viewer stands."
  def thread(round_id, viewer_id \\ nil),
    do: [round_id] |> threads_for(viewer_id) |> Map.get(round_id, [])

  # THE VIEWER'S READING OF A ROW BOTH OF THEM CAN SEE. One row, two readings,
  # and no way for the two sides to hold different versions of what was said.
  #
  # YOUR OWN WORDS SAY "YOU" RATHER THAN YOUR NAME, because a round read from
  # where you stand is a conversation and not a transcript.
  defp read_from(%Word{} = w, viewer_id) do
    mine = w.person_id == viewer_id

    %{
      id: w.id,
      body: w.body,
      images: w.images,
      mine?: mine,
      by: (mine && "YOU") || String.upcase(w.person.name),
      when: Clock.since(w.inserted_at)
    }
  end

  def limit, do: Word.limit()
end
