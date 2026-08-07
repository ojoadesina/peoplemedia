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

  alias Peoplemedia.Repo
  alias Peoplemedia.Words.Word

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
         heard: Enum.count(words, &(&1.person_id != viewer_id))
       }}
    end)
  end

  @doc "Every word in one round, oldest first — the thread, as it was said."
  def thread(round_id) do
    Word
    |> where([w], w.round_id == ^round_id)
    |> order_by([w], asc: w.id)
    |> Repo.all()
  end

  def limit, do: Word.limit()
end
