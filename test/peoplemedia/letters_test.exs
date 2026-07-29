defmodule Peoplemedia.LettersTest do
  @moduledoc """
  A letter is addressed ONCE — to a relationship, or to an audience.

  Most of what is here guards the seam between those two, because that is where
  the damage would be silent: a letterhead leaking into a correspondence is a
  thing said to everyone appearing in a conversation between two people, and
  nothing on the surface would look wrong while it happened.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{Letters, Relationships}
  alias Peoplemedia.Letters.Letter

  import Peoplemedia.Fixtures

  describe "letterheads" do
    test "one is written with an audience and no relationship" do
      me = person("OJO")

      assert {:ok, head} = Letters.broadcast(me.id, "world", %{kind: "text", body: "hello all"})
      assert head.audience == "world"
      assert is_nil(head.relationship_id)
      assert head.sender_id == me.id
    end

    test "both audiences are allowed and nothing else is" do
      me = person("OJO")

      for audience <- ~w(relationships world) do
        assert {:ok, _} = Letters.broadcast(me.id, audience, %{kind: "text", body: "x"})
      end

      assert {:error, changeset} =
               Letters.broadcast(me.id, "everyone", %{kind: "text", body: "x"})

      assert "is invalid" in errors_on(changeset).audience
    end

    test "one with no words is refused, the same as any other text letter" do
      me = person("OJO")

      assert {:error, changeset} = Letters.broadcast(me.id, "world", %{kind: "text", body: ""})
      assert errors_on(changeset).body != []
    end

    # A LETTERHEAD IS NOT ADDRESSED, so there is nobody for a tie to be about.
    # `write/3` opens one because it needs somewhere to hang the letter; this
    # path has an audience instead, and creating a relationship here would be
    # the app inventing a connection out of somebody talking.
    test "writing one opens no relationship with anybody" do
      me = person("OJO")
      them = person("SARAH")

      {:ok, _} = Letters.broadcast(me.id, "world", %{kind: "text", body: "hello all"})

      assert Relationships.not_held_by(me.id) |> Enum.map(& &1.id) == [them.id]
      assert Letters.thread(me.id, them.id) == []
    end

    test "they come back newest first, read from the writer's own side" do
      me = person("OJO")

      {:ok, _} = Letters.broadcast(me.id, "world", %{kind: "text", body: "the older one"})
      {:ok, _} = Letters.broadcast(me.id, "relationships", %{kind: "text", body: "the newer one"})

      assert [newest, oldest] = Letters.broadcasts_by(me.id)
      assert newest.body == "the newer one"
      assert oldest.body == "the older one"
      # From your own side every one of them is yours, which is the only side
      # there is to read a letterhead from today.
      assert newest.from == "you"
      assert newest.by == "YOU"
    end

    test "somebody else's letterheads are not yours" do
      me = person("OJO")
      them = person("SARAH")

      {:ok, _} = Letters.broadcast(them.id, "world", %{kind: "text", body: "theirs"})

      assert Letters.broadcasts_by(me.id) == []
      assert [%{body: "theirs"}] = Letters.broadcasts_by(them.id)
    end
  end

  describe "the seam between the two kinds" do
    setup do
      me = cast()
      [{_scope, them} | _] = Relationships.held_by(me.id)
      %{me: me, them: them}
    end

    # THE ONE THAT WOULD BE SILENT. A thread asks for one relationship id and
    # NULL is not one, so this holds by construction — which is exactly why it
    # is worth a test: nothing would fail loudly the day the query changed.
    test "a letterhead never appears in a correspondence", %{me: me, them: them} do
      before = Letters.thread(me.id, them.id)

      {:ok, _} = Letters.broadcast(me.id, "relationships", %{kind: "text", body: "to everyone"})

      assert Letters.thread(me.id, them.id) == before
      assert Letters.thread(them.id, me.id) |> Enum.all?(&(&1.body != "to everyone"))
    end

    test "and a letter to one person never appears among the letterheads", %{me: me, them: them} do
      {:ok, _} = Letters.write(me.id, them.id, %{kind: "text", body: "just for you"})

      assert Letters.broadcasts_by(me.id) == []
    end

    # The database says it too, about rows this module never sees.
    test "a letter addressed to neither is refused by the row itself" do
      me = person("OJO")

      assert_raise Ecto.ConstraintError, ~r/letters_have_one_target/, fn ->
        Repo.insert(%Letter{sender_id: me.id, kind: "text", body: "orphan"})
      end
    end

    test "and so is one addressed to both", %{me: me, them: them} do
      {:ok, letter} = Letters.write(me.id, them.id, %{kind: "text", body: "just for you"})

      assert_raise Ecto.ConstraintError, ~r/letters_have_one_target/, fn ->
        letter |> Ecto.Changeset.change(audience: "world") |> Repo.update()
      end
    end
  end
end
