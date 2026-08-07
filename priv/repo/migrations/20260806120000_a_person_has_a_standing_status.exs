defmodule Peoplemedia.Repo.Migrations.APersonHasAStandingStatus do
  @moduledoc """
  WHAT SOMEBODY IS DOING WHEN THEY ARE NOT ROUND.

  A round is deliberate and it expires. Most people are not in one most of the
  time, which left the second block of their item holding nothing — and a blank
  panel under every second name is the column reporting an absence over and over.

  A STATUS IS THE OPPOSITE OF A ROUND IN EVERY WAY THAT MATTERS. It is standing
  rather than made, it does not expire, and it is not an invitation: "at work"
  says where you are, not that you want joining. That is exactly why it can sit
  in the place a round would take without ever being mistaken for one.

  NULLABLE, because having nothing to say is a real answer and the commonest one.
  """
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :status, :string
    end
  end
end
