defmodule Peoplemedia.Clock do
  @moduledoc """
  HOW LONG AGO, IN ONE SHORT TOKEN — `2m`, `3h`, `4d`.

  IT LIVED IN `Letters` AND HAD NOTHING TO DO WITH LETTERS. It was written there
  because a letter was the first thing on this surface that needed an age, and it
  stayed there after a ROUND became the second — so the item's head was reaching
  into the letters context to date a round. A shared answer belongs to neither of
  the things that share it.

  ONE VOCABULARY, OR TWO MEASUREMENTS. Everything on this surface that says when
  says it in these tokens; two clocks written two ways read as two different
  facts, which is the whole reason this is one function rather than a habit.

  SHORT BY DESIGN. An age is an ASIDE — it trails a name, it is not a heading —
  and `YESTERDAY` was nine tracked characters answering a question nobody had
  asked yet.
  """

  def since(%DateTime{} = at),
    do: relative(max(div(DateTime.diff(DateTime.utc_now(), at), 60), 0))

  def since(%NaiveDateTime{} = at), do: since(DateTime.from_naive!(at, "Etc/UTC"))
  def since(nil), do: nil

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
end
