# THE CAST, AS REAL ROWS.
#
# These names were module attributes in `Peoplemedia.Directory` for as long as
# the app had no database. They are seed data now, which is what they always
# were — the difference is that a scope is a ROW JOINING TWO PEOPLE rather than
# a `label:` field sitting beside a name, and that difference is the whole point
# of the stage this arrived in.
#
# IDEMPOTENT. Running it twice adds nobody: everyone is looked up by name first.

import Ecto.Query

alias Peoplemedia.{Identity, Letters, People, Relationships}
alias Peoplemedia.People.Person
alias Peoplemedia.Repo

countries = Enum.map(Peoplemedia.Directory.countries(), & &1.name)

find_or_create = fn name, country ->
  case Repo.one(from p in Person, where: p.name == ^name) do
    nil ->
      {:ok, p} = People.create_person(%{name: name, country: country})
      p

    %Person{} = p ->
      p
  end
end

# THE DEMO OWNER. Somebody has to be holding these relationships, because a
# scope has an owner by definition — an unowned list is not a thing this schema
# can express. The passport is real, so you can check in as them and see the
# list the fixtures used to show.
#
#     name: ojo    words: harbour lantern thistle    code: 4417
me = find_or_create.("ojo", "Finland")

if is_nil(Identity.get_passport(me.id)) do
  {:ok, _} = Identity.create_passport(me, "ojo", ~w(harbour lantern thistle), "4417")
end

# EVERYONE OJO HOLDS. The label is ojo's word for them; the name is their own,
# and the two live in different tables precisely so both can be true at once.
held = [
    {"MUM", "SARAH"},
    {"DAD", "MICHAEL"},
    {"BIG BROTHER", "DANIEL OLUWASEUN"},
    {"BROTHER", "JOSEPH"},
    {"SISTER", "AMAKA"},
    {"GRANDMA", "ROSE"},
    {"COACH", "IBRAHIM"},
    {"BEST FRIEND", "TUNDE ADEBAYO"},
    {"NEIGHBOUR", "ELENA"},
    {"COUSIN", "KEMI"},
    {"UNCLE", "PETER"},
    {"AUNT", "BLESSING"},
    {"MENTOR", "ADEOLA"},
    {"ROOMMATE", "LUCAS"},
    {"BOSS", "HANNAH"},
    {"DOCTOR", "NGOZI"},
    {"BARBER", "FEMI"},
    {"PASTOR", "EMMANUEL"},
    {"TEAMMATE", "CHIDI"}
]

# AND A LETTER OR TWO EACH, in all three kinds and both directions. The row
# summary has four arrow states, three marks and an unread signal; a cast whose
# threads all looked the same would leave most of the surface drawing nothing.
#
#   {who wrote it, whether the recipient opened it, what it arrived as}
threads = [
  [{:them, false, "voice"}],
  [{:you, true, "face"}],
  [{:them, true, "text"}, {:you, true, "voice"}],
  [{:you, false, "text"}, {:them, true, "face"}],
  [{:them, false, "face"}, {:you, true, "text"}],
  [],
  [{:them, true, "voice"}],
  [{:you, true, "text"}]
]

held
|> Enum.with_index()
|> Enum.each(fn {{label, name}, i} ->
  person = find_or_create.(name, Enum.at(countries, rem(i, length(countries))))

  unless Relationships.related?(me.id, person.id) do
    # THE FULL THREE ROUNDS, so these end up `scoped` rather than left pending:
    # ojo asks, they scope back with their own word for ojo, ojo confirms.
    {:ok, _} = Relationships.request_scope(me.id, person.id, label)
    {:ok, _} = Relationships.scope_back(person.id, me.id, "OJO")
    {:ok, _} = Relationships.accept(me.id, person.id)
  end

  # Oldest written first, so the last one is the newest — the one the row speaks
  # for. Skipped entirely if this thread already has letters, or a second run
  # would double every conversation.
  if Letters.thread(me.id, person.id) == [] do
    for {who, read, kind} <- Enum.reverse(Enum.at(threads, rem(i, length(threads)))) do
      sender = (who == :you && me) || person
      recipient = (who == :you && person) || me

      attrs =
        case kind do
          "text" -> %{kind: "text", body: "Thinking of you."}
          other -> %{kind: other, media: nil}
        end

      {:ok, _} = Letters.write(sender.id, recipient.id, attrs)
      if read, do: Letters.mark_read(recipient.id, sender.id)
    end
  end
end)

# EVERYONE OJO DOES NOT HOLD. People rows like anyone else — that is what makes
# the UNSCOPED list a QUERY rather than a second fixture, and what gives
# swipe-to-scope something real to act on.
strangers = [
    "AMINA",
    "LEV",
    "PRIYA",
    "TARKHAN",
    "SOPHIE",
    "JERIES",
    "MATEO",
    "YERNUR",
    "HANA",
    "OMAR",
    "ULADZISLAU",
    "FREYA",
    "RIZKI",
    "NOA",
    "DIEGO"
]

strangers
|> Enum.with_index()
|> Enum.each(fn {name, i} ->
  find_or_create.(name, Enum.at(countries, rem(i + 7, length(countries))))
end)

people = Repo.aggregate(Person, :count)
scopes = Repo.aggregate(Peoplemedia.Relationships.Scope, :count)
letters = Repo.aggregate(Peoplemedia.Letters.Letter, :count)

IO.puts(
  "seeded: " <>
    to_string(people) <>
    " people, " <> to_string(scopes) <> " scopes, " <> to_string(letters) <> " letters"
)
