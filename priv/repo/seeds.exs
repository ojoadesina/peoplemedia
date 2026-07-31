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

# THE PLACE IS PART OF THE SEED, not just the name. Where somebody lives decides
# which list they appear in now, so a run that changed the distribution and left
# everyone standing where the last run put them would seed one thing and show
# another. Existing rows are moved rather than duplicated — the name is still
# the identity.
find_or_create = fn name, country ->
  case Repo.one(from p in Person, where: p.name == ^name) do
    nil ->
      {:ok, p} = People.create_person(%{name: name, country: country})
      p

    %Person{country: ^country} = p ->
      p

    %Person{} = p ->
      {:ok, moved} = People.update_person(p, %{country: country})
      moved
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

# WHERE THEY LIVE, and most of them live where ojo does. The place box is the
# list's parent now — pick Finland and you see Finland — so a cast spread evenly
# over eighteen countries would give every place a list of one and the home page
# a list of one, which is a worse demonstration than it is a distribution. Home
# holds the bulk; the rest are abroad so the roll of places is not decoration.
home = "Finland"
abroad = Enum.reject(countries, &(&1 == home))
somewhere = fn i, from_home -> (i < from_home && home) || Enum.at(abroad, rem(i, length(abroad))) end

held
|> Enum.with_index()
|> Enum.each(fn {{label, name}, i} ->
  person = find_or_create.(name, somewhere.(i, 12))

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
  find_or_create.(name, somewhere.(i, 9))
end)

# ── THE MASTER PASSPORT ──────────────────────────────────────────────────────
#
#     name: angel    word: angel    code: 0000
#
# One word, one code, both the same as the handle, so checking in during
# development costs no memory at all.
#
# ITS WORDS ARE NOT SPENT, and that is a config line rather than anything here:
# `master_handle` in config/dev.exs and config/prod.exs names this handle, and
# Identity skips the burn for it. So the bank is three words like anybody else's.
#
# WHAT THIS REPLACES was twelve copies of the same word, added one batch at a
# time because the no-repeats rule only looks within a single submission. It
# passed every check and broke what the rule means, and it cost a deploy: twelve
# bcrypt hashes inside the release command stalled the seed long enough for the
# database's proxy to time out its own health check and drop every session.
#
# THE SEED MAKES REALITY MATCH, rather than only filling in what is missing.
# "Idempotent" here used to mean "does nothing if a passport exists", which
# cannot REPAIR one — and the deployed angel ended up with a code that did not
# open it, so the documented password was wrong and no amount of re-seeding
# could put it right. For the one account whose credentials are written down in
# a comment, the seed has to assert them.
angel = find_or_create.("angel", home)

if is_nil(Identity.get_passport(angel.id)) do
  {:ok, _} = Identity.create_passport(angel, "angel", ~w(angel wings halo), "0000")
end

{:ok, _} = Identity.reset_code(Identity.get_passport(angel.id), "0000")

# AND SOMEBODY TO LOOK AT. An account whose list is empty tests the empty state
# and nothing else, so angel holds a handful of the people at home and has one
# handshake open in each direction — which is the only way to reach the two
# answering paths in the scoping room without setting them up by hand.
angel_held = [{"MUM", "SARAH"}, {"BROTHER", "JOSEPH"}, {"COACH", "IBRAHIM"}, {"NEIGHBOUR", "ELENA"}]

for {label, name} <- angel_held do
  person = find_or_create.(name, home)

  unless Relationships.related?(angel.id, person.id) do
    {:ok, _} = Relationships.request_scope(angel.id, person.id, label)
    {:ok, _} = Relationships.scope_back(person.id, angel.id, "ANGEL")
    {:ok, _} = Relationships.accept(angel.id, person.id)
  end

  if Letters.thread(angel.id, person.id) == [] do
    {:ok, _} = Letters.write(person.id, angel.id, %{kind: "text", body: "Are you around later?"})
  end
end

%{incoming: incoming, outgoing: outgoing} = Relationships.pending_scopes_for(angel.id)

if incoming == [] do
  asker = find_or_create.("LEV", home)
  unless Relationships.related?(angel.id, asker.id),
    do: {:ok, _} = Relationships.request_scope(asker.id, angel.id, "FRIEND")
end

if outgoing == [] do
  asked = find_or_create.("PRIYA", home)
  unless Relationships.related?(angel.id, asked.id),
    do: {:ok, _} = Relationships.request_scope(angel.id, asked.id, "CLASSMATE")
end

people = Repo.aggregate(Person, :count)
scopes = Repo.aggregate(Peoplemedia.Relationships.Scope, :count)
letters = Repo.aggregate(Peoplemedia.Letters.Letter, :count)

IO.puts(
  "seeded: " <>
    to_string(people) <>
    " people, " <> to_string(scopes) <> " scopes, " <> to_string(letters) <> " letters"
)

# ── WHO IS ROUND ──────────────────────────────────────────────────────────────
# The list is people-first and never a feed, so what makes it worth looking at is
# who has gone round: a name, a mood, a doing. A seed in which nobody has would
# draw the surface's newest boxes empty on every row — and `absent`, which is
# half of what a row can say, would be the only half anybody saw.
alias Peoplemedia.{Presence, Rounds}

rounds = [
  {"SARAH", %{doing: "the witchers, finally", mood: "happy"}},
  {"KEMI", %{doing: "walking it off", mood: "sad"}},
  {"IBRAHIM", %{doing: "hill sprints before the rain", mood: "restless"}},
  {"ELENA", %{doing: "borscht, third attempt", mood: "content"}},
  {"MICHAEL", :here_only},
  {"ROSE", :here_only}
]

for {name, said} <- rounds,
    person = Repo.one(from p in Person, where: p.name == ^name) do
  {:ok, _} = Presence.touch(person.id)
  if said != :here_only, do: {:ok, _} = Rounds.go(person.id, said)
end

IO.puts("round: #{length(rounds)} of them")
