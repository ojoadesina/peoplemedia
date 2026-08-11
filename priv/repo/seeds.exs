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

alias Peoplemedia.{Identity, People, Presence, Relationships, Rounds, Words}
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

# AND A ROUND EACH, OR NOT. A row is drawn from a round, so a sheet where
# everybody was round would show only one of the three things a row can be.
#
# LIVE, EXPIRED, OR NONE AT ALL. Expiry is about VISIBILITY and never deletion —
# an expired round keeps its words and its place in the person's history and
# simply stops surfacing them — so the sheet has to carry one to show that the
# list does not demote anybody for going quiet.
#
lives = [:live, :live, :live, :expired, :expired, :none, :live, :none]

# ── AND WHAT THEY CAPTURED OF THEMSELVES ─────────────────────────────────────
# A face, a voice or a still, on the PERSON — theirs, and the same whoever is
# looking. It hung off the last letter for a while, which made a stranger's frame
# empty by definition and left most of the column showing nothing at all.
#
# MOST PEOPLE HAVE CAPTURED NOTHING, which is the resting state and has to be on
# the sheet or the design is only ever judged against a full column.
#
# BORROWED AND PUBLIC, and they go the day this app can capture anything itself:
# small CC-licensed clips from test-videos.co.uk and photographs from picsum.
#
# A STILL IS A PHOTOGRAPH. It was a drawn gradient for a while, which was never
# discussed and was wrong twice over — a drawing is not what the field holds, and
# dark ones under a scrim were indistinguishable from a frame that had failed to
# load. Real pictures, so the state can actually be judged.
face_clip = "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4"
voice_clip = "https://test-videos.co.uk/vids/jellyfish/mp4/h264/360/Jellyfish_360_10s_1MB.mp4"

captures = [
  {"face", face_clip},
  {nil, nil},
  {"voice", voice_clip},
  {"still", "https://picsum.photos/id/1015/600/400"},
  {nil, nil},
  {"face", face_clip},
  {nil, nil},
  {"still", "https://picsum.photos/id/1043/600/400"},
  {"voice", voice_clip},
  {nil, nil}
]

Repo.all(Person)
|> Enum.with_index()
|> Enum.each(fn {person, i} ->
  {kind, file} = Enum.at(captures, rem(i, length(captures)))

  person
  |> Ecto.Changeset.change(%{capture_kind: kind, capture: file})
  |> Repo.update!()
end)

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

  # ONE ROUND EACH. Skipped entirely if they already have one, or a second run
  # would give everybody a fresh round and the sheet would never show an expired
  # one. What gets SAID in them is filled in further down, once every round in
  # the file exists.
  if Enum.at(lives, rem(i, length(lives))) != :none and Rounds.history(person.id, me.id) == [] do
    # PRIVATE, SO OJO IS IN THE AUDIENCE. A public round is seen by everybody and
    # so proves nothing about the read that decides who may see one.
    {:ok, _} = Rounds.go(person.id, %{"audience" => "private"})

    # RUN OUT, NOT STOPPED. Stopping is somebody CHOOSING to stop surfacing; this
    # is the clock, which is the state most rounds on a real list are in — and
    # the two are the same column and a different act.
    if Enum.at(lives, rem(i, length(lives))) == :expired do
      from(r in Peoplemedia.Rounds.Round, where: r.person_id == ^person.id)
      |> Repo.update_all(set: [expires_at: DateTime.utc_now() |> DateTime.add(-60, :second)])
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

# ── AND ONE PERSON WITH A HISTORY ────────────────────────────────────────────
# EVERY OTHER PERSON HERE HAS AT MOST ONE ROUND, because the guard above gives
# them one and then leaves them alone. That draws the LIST correctly and draws a
# PAGE wrongly: a page is the rounds somebody has gone, newest first, and one
# round is a page that cannot show it is a list at all.
#
# EXPIRED ONES ARE THE POINT OF IT. Law 4 — expiry is about visibility, never
# deletion — so an old round keeps its words and comes back on the page after it
# has stopped surfacing them on anybody's list. Nothing else in this file
# demonstrates that.
sarah = Repo.one(from p in Person, where: p.name == "SARAH")

if sarah && length(Rounds.history(sarah.id, me.id)) < 2 do
  {:ok, older} = Rounds.go(sarah.id, %{"audience" => "private"})
  {:ok, _} = Words.say(older.id, sarah.id, "off to the market, back by two")
  {:ok, _} = Words.say(older.id, me.id, "get me the good bread")
  {:ok, _} = Words.say(older.id, sarah.id, "they had none left")

  # OLDER IN EVERY SENSE. Setting only `expires_at` back made a round that was
  # INSERTED after her live one and had already run out — which cannot happen,
  # and which put the expired round above the live one on her page. A page is
  # ordered by when each round was gone, so the age has to move too.
  then = NaiveDateTime.utc_now(:second) |> NaiveDateTime.add(-3, :day)

  from(r in Peoplemedia.Rounds.Round, where: r.id == ^older.id)
  |> Repo.update_all(
    set: [
      inserted_at: then,
      expires_at: DateTime.utc_now() |> DateTime.add(-3, :day) |> DateTime.truncate(:second)
    ]
  )

  # AND THE WORDS WITH IT. Each word carries its own age on the page, so words
  # left at today's clock inside a three-day-old round read as a conversation
  # that happened after the round it is in.
  from(w in Peoplemedia.Words.Word, where: w.round_id == ^older.id)
  |> Repo.update_all(set: [inserted_at: then])
end

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

  if Rounds.history(person.id, angel.id) == [] do
    {:ok, round} = Rounds.go(person.id, %{"audience" => "private"})
    {:ok, _} = Words.say(round.id, person.id, "are you around later?")
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

# ── WHO IS ROUND ──────────────────────────────────────────────────────────────
# The list is people-first and never a feed, so what makes it worth looking at is
# who has gone round. A seed in which nobody has would
# draw the surface's newest boxes empty on every row — and `absent`, which is
# half of what a row can say, would be the only half anybody saw.
# PRESENCE, WHICH IS A DIFFERENT QUESTION FROM A ROUND. Being here is a state and
# going round is an act — the rounds above are already made, and this is the other
# half: who has the app open. Some of these are round and some are only here, so
# the row's two answers are both on the sheet.
for name <- ~w(SARAH KEMI IBRAHIM ELENA MICHAEL ROSE),
    person = Repo.one(from p in Person, where: p.name == ^name) do
  {:ok, _} = Presence.touch(person.id)
end

# ── AND WORDS INSIDE THE ROUNDS ───────────────────────────────────────────────
# A round surfaces a person; the words are what gets said once they are surfaced.
# The surface draws two things from them — the last one, on the item's second
# block, and how many there are, at its trailing edge — so a sheet where every
# round held the same number would show neither working.
#
# SOME ROUNDS HOLD NONE. Going round is one tap and saying something is another,
# so a round nobody has spoken in yet is the commonest state there is and the one
# the design has to survive: no count, and a block with only the round's name.
#
# BOTH DIRECTIONS. Some are the creator's, some are ojo's, because the arrows on
# an item say which way the conversation has gone and a thread that only ever ran
# one way would draw one arrow for ever.
said = [
  ["Nearly there. The beetroot is winning."],
  [],
  ["Third lap.", "Rain held off.", "Legs gone."],
  ["Anyone seen my other glove"],
  [],
  ["Halfway up and regretting the shoes", "Worth it for the view though"],
  ["Two episodes in"],
  []
]

Peoplemedia.Repo.all(Peoplemedia.Rounds.Round)
|> Enum.with_index()
# SKIPPED IF SOMETHING IS ALREADY IN IT, or a second run doubles every round's
# conversation — the same guard the rounds and the scopes above are written with,
# and the reason this file can be run twice.
#
# THE GUARD IS OUT HERE, NOT IN THE COMPREHENSION. As a filter it would be asked
# again for every word, and the first insert makes the answer no — so every round
# in the file would get its opening line and nothing after it.
|> Enum.reject(fn {round, _i} -> Words.thread(round.id) != [] end)
|> Enum.each(fn {round, i} ->
  for {body, n} <- Enum.with_index(Enum.at(said, rem(i, length(said)))) do
    # EVERY OTHER ONE IS OJO'S, so both arrows have something to say.
    who = if rem(n, 2) == 1, do: me.id, else: round.person_id

    # SOME WORDS CARRY PICTURES AND MOST DO NOT. The item draws a stack for a
    # round that has any, so a sheet where every round had them would show
    # nothing about when the stack appears — which is most of what it says.
    pictures =
      case rem(i * 3 + n, 5) do
        0 -> ["https://picsum.photos/id/1025/200/200", "https://picsum.photos/id/1039/200/200"]
        3 -> ["https://picsum.photos/id/1025/200/200"]
        _ -> []
      end

    {:ok, _} = Words.say(round.id, who, body, images: pictures)
  end
end)

# WHAT THIS FILE MADE, counted at the END of it. It sat above the words and so
# reported a number taken before they existed — a fresh database seeded 675 words
# and announced nought.
people = Repo.aggregate(Person, :count)
scopes = Repo.aggregate(Peoplemedia.Relationships.Scope, :count)
words = Repo.aggregate(Peoplemedia.Words.Word, :count)

IO.puts(
  "seeded: " <>
    to_string(people) <>
    " people, " <> to_string(scopes) <> " scopes, " <> to_string(words) <> " words"
)
