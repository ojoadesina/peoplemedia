defmodule Peoplemedia.NotificationsTest do
  @moduledoc """
  The notification spine. What matters here is not that rows insert — it is that
  `notify/4` COLLAPSES repeats onto one unread row, because that is the
  difference between a badge counting events and a badge counting people who
  want something from you.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{Notifications, People}

  defp person(name) do
    {:ok, p} = People.create_person(%{name: name, country: "Finland"})
    p
  end

  setup do
    %{me: person("Me"), them: person("Them"), other: person("Other")}
  end

  test "a repeated ask bumps one row rather than stacking two", %{me: me, them: them} do
    {:ok, _} = Notifications.notify(me.id, "scope_request", them.id, %{"label" => "DAD"})
    {:ok, _} = Notifications.notify(me.id, "scope_request", them.id, %{"label" => "FATHER"})

    assert Notifications.unread_count(me.id) == 1
    # And the LATEST payload wins — the row is the current state of the ask.
    assert [%{data: %{"label" => "FATHER"}}] = Notifications.list(me.id)
  end

  test "different actors are different news", %{me: me, them: them, other: other} do
    {:ok, _} = Notifications.notify(me.id, "scope_request", them.id)
    {:ok, _} = Notifications.notify(me.id, "scope_request", other.id)
    assert Notifications.unread_count(me.id) == 2
  end

  test "an actorless notification is its own row and does not crash on nil", %{me: me} do
    # The nil actor is branched in Elixir rather than SQL on purpose — a pinned
    # `is_nil(^actor_id)` sends Postgres an untyped parameter and it refuses.
    {:ok, _} = Notifications.notify(me.id, "welcome")
    {:ok, _} = Notifications.notify(me.id, "welcome")
    assert Notifications.unread_count(me.id) == 1
  end

  test "reading clears the badge, and only for the kinds asked for", %{me: me, them: them} do
    {:ok, _} = Notifications.notify(me.id, "scope_request", them.id)
    {:ok, _} = Notifications.notify(me.id, "letter", them.id)
    assert Notifications.unread_count(me.id) == 2

    assert Notifications.mark_read(me.id, ["scope_request"]) == 1
    assert Notifications.count_kinds(me.id, ["scope_request"]) == 0
    assert Notifications.count_kinds(me.id, ["letter"]) == 1
  end

  test "one person's news is never another's", %{me: me, them: them} do
    {:ok, _} = Notifications.notify(me.id, "letter", them.id)
    assert Notifications.unread_count(me.id) == 1
    assert Notifications.unread_count(them.id) == 0
  end

  test "a read notification stops collapsing — the next one is new news", %{me: me, them: them} do
    {:ok, _} = Notifications.notify(me.id, "scope_request", them.id)
    Notifications.mark_read(me.id, :all)
    {:ok, _} = Notifications.notify(me.id, "scope_request", them.id)

    assert Notifications.unread_count(me.id) == 1
    assert length(Notifications.list(me.id)) == 2
  end
end
