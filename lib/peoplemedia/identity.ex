defmodule Peoplemedia.Identity do
  @moduledoc """
  The Identity context — the single entry point for all passport operations
  (create, check-in, top-up, strength). No other module touches the passport
  tables directly.

  PORTED WHOLE from the project this app grew out of, person-for-figure. The
  model: a person signs in with their
  **nickname + a one-time secret word + a 4-digit code**. Check-in is two steps —
  match the word against the bank (`check_key/2`), then verify the code
  (`check_code/3`). The word is burned ONLY when both are right, so a leaked word
  is single-use and the code is the constant second factor. Lockouts cap brute
  force on each step.

  RECOVERY IS PERSON-FIRST: you top up your own word bank before it runs out,
  and `needs_renewal?/1` is what tells the surface to ask. There is no email
  reset path and no email address anywhere in this context — deliberately, since
  an app about people you actually know should not need a mail provider to let
  you back in.
  """

  import Ecto.Query, warn: false

  alias Peoplemedia.Repo
  alias Peoplemedia.People.Person
  alias Peoplemedia.Identity.{Passport, PassportSecret, PassportHandle}

  # ── Tunables ────────────────────────────────────────────────────────────────
  @min_secrets_registration 3
  @max_secrets_per_batch 30
  @min_secret_length 3
  @secret_format ~r/^[a-zA-Z]+$/
  # A handle rides a list row beside a name, so it stays short and plain:
  # 2–10 alphanumerics, normalised to lower case for the lookup.
  @handle_format ~r/^[a-z0-9]{2,10}$/
  @renewal_threshold 40
  @key_max_attempts 5
  @key_lockout_minutes 10
  @code_max_attempts 3
  @code_lockout_minutes 5
  # BCRYPT COST, overridable so the test suite is not spending real seconds
  # proving bcrypt works. The passport hashes a code and EVERY word in the bank,
  # so a single sign-up is a dozen hashes; at production cost that is seconds per
  # test. config/test.exs turns it down, and nothing else may.
  @bcrypt_secret_rounds Application.compile_env(:peoplemedia, :bcrypt_secret_rounds, 10)
  @bcrypt_code_rounds Application.compile_env(:peoplemedia, :bcrypt_code_rounds, 12)

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Create a passport for an already-inserted `person`: claims the nickname, stores
  the bank of one-time words and the 4-digit code (all hashed), in one
  transaction. Returns `{:ok, %Passport{}}` or `{:error, atom | changeset}`.
  """
  def create_passport(%Person{} = person, nickname, secret_words, code) do
    with :ok <- validate_nickname(nickname),
         :ok <- validate_secrets(secret_words, @min_secrets_registration),
         :ok <- validate_code(code) do
      code_hash = Bcrypt.hash_pwd_salt(code, log_rounds: @bcrypt_code_rounds)
      handle_code = normalize_handle(nickname)

      Repo.transaction(fn ->
        with {:ok, passport} <- insert_passport(person.id, code_hash),
             {:ok, _handle} <- insert_handle(passport.id, handle_code),
             :ok <- insert_secrets(passport.id, secret_words) do
          passport
        else
          {:error, %Ecto.Changeset{} = cs} -> Repo.rollback(changeset_reason(cs))
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  @doc "Is this nickname free (and well-formed)? For live availability hints in the UI."
  def handle_available?(nickname) do
    case validate_nickname(nickname) do
      :ok -> is_nil(get_passport_by_handle(normalize_handle(nickname)))
      _ -> false
    end
  end

  @doc """
  Check-in step 1 — validate nickname + secret word. Constant-time on failure to
  avoid leaking which nicknames exist.

  Returns `{:ok, passport, secret_id}` | `{:error, :invalid_credentials}` |
  `{:error, :locked, seconds}`.
  """
  def check_key(nickname, secret_word) do
    passport = get_passport_by_handle(normalize_handle(nickname))

    if is_nil(passport) do
      Bcrypt.no_user_verify()
      {:error, :invalid_credentials}
    else
      do_check_key(passport, secret_word)
    end
  end

  @doc """
  Check-in step 2 — verify the 4-digit code and BURN the matched word. The word
  is burned only here (when both key and code are right).

  Returns `{:ok, %Person{}}` | `{:error, :wrong_code}` | `{:error, :locked, seconds}`.
  """
  def check_code(%Passport{} = passport, code, secret_id) do
    case check_lockout(passport) do
      {:locked, seconds} ->
        {:error, :locked, seconds}

      :ok ->
        if Bcrypt.verify_pass(code, passport.code_hash) do
          burn_secret(secret_id)
          reset_code_attempts(passport)
          update_strength(passport, recompute_strength(passport.id))
          {:ok, Repo.get(Person, passport.person_id)}
        else
          case increment_code_attempts(passport) do
            {:locked, seconds} -> {:error, :locked, seconds}
            :ok -> {:error, :wrong_code}
          end
        end
    end
  end

  @doc "Top up an existing passport's word bank (1–30 new words). Returns `{:ok, %Passport{}}`."
  def add_secrets(%Passport{} = passport, new_secret_words) do
    with :ok <- validate_secrets(new_secret_words, 1) do
      Repo.transaction(fn ->
        max_order = get_max_secret_order(passport.id)

        case insert_secrets(passport.id, new_secret_words, max_order) do
          :ok ->
            update_strength(passport, recompute_strength(passport.id))
            Repo.preload(passport, :secrets, force: true)

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)
    end
  end

  @doc "Load a passport (with secrets preloaded) for a person id, or nil."
  def get_passport(person_id) do
    Repo.one(from(p in Passport, where: p.person_id == ^person_id, preload: :secrets))
  end

  @doc "Word-bank health: active ÷ total × 100 (0 when empty)."
  def passport_strength(passport_id) do
    total = count_secrets(passport_id, nil)
    active = count_secrets(passport_id, "active")
    if total == 0, do: 0, else: round(active / total * 100)
  end

  @doc "True when the word bank is running low (strength < 40%) and should be topped up."
  def needs_renewal?(%Passport{strength: strength}), do: strength < @renewal_threshold

  # ============================================================================
  # Private helpers
  # ============================================================================

  defp do_check_key(%Passport{} = passport, secret_word) do
    case check_lockout(passport) do
      {:locked, seconds} ->
        {:error, :locked, seconds}

      :ok ->
        match =
          passport.id
          |> get_active_secrets()
          |> Enum.find(fn s -> Bcrypt.verify_pass(secret_word, s.secret_hash) end)

        if match do
          reset_key_attempts(passport)
          {:ok, passport, match.id}
        else
          increment_key_attempts(passport)
          {:error, :invalid_credentials}
        end
    end
  end

  defp validate_nickname(nickname) when is_binary(nickname) do
    if Regex.match?(@handle_format, normalize_handle(nickname)),
      do: :ok,
      else: {:error, :invalid_nickname}
  end

  defp validate_nickname(_), do: {:error, :invalid_nickname}

  defp validate_secrets(words, min_count) do
    cond do
      not is_list(words) ->
        {:error, :invalid_secret_format}

      length(words) < min_count ->
        {:error, :too_few_secrets}

      length(words) > @max_secrets_per_batch ->
        {:error, :too_many_secrets}

      Enum.any?(words, &(String.length(&1) < @min_secret_length)) ->
        {:error, :invalid_secret_format}

      Enum.any?(words, &(!Regex.match?(@secret_format, &1))) ->
        {:error, :invalid_secret_format}

      length(Enum.uniq(words)) != length(words) ->
        {:error, :duplicate_secrets}

      true ->
        :ok
    end
  end

  defp validate_code(code) do
    if is_binary(code) and Regex.match?(~r/^\d{4}$/, code),
      do: :ok,
      else: {:error, :invalid_code_format}
  end

  defp normalize_handle(nickname),
    do: nickname |> to_string() |> String.trim() |> String.downcase()

  defp insert_passport(person_id, code_hash) do
    %Passport{}
    |> Passport.changeset(%{person_id: person_id, code_hash: code_hash})
    |> Repo.insert()
  end

  defp insert_handle(passport_id, handle_code) do
    %PassportHandle{}
    |> PassportHandle.changeset(%{passport_id: passport_id, handle_code: handle_code})
    |> Repo.insert()
  end

  defp insert_secrets(passport_id, words, start_order \\ 0) do
    results =
      words
      |> Enum.with_index(start_order + 1)
      |> Enum.map(fn {word, order} ->
        hash = Bcrypt.hash_pwd_salt(word, log_rounds: @bcrypt_secret_rounds)

        %PassportSecret{}
        |> PassportSecret.changeset(%{passport_id: passport_id, secret_hash: hash, order: order})
        |> Repo.insert()
      end)

    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil -> :ok
      error -> error
    end
  end

  defp get_active_secrets(passport_id) do
    Repo.all(
      from(s in PassportSecret,
        where: s.passport_id == ^passport_id and s.status == "active",
        order_by: [asc: :order]
      )
    )
  end

  defp burn_secret(secret_id) do
    Repo.get!(PassportSecret, secret_id)
    |> PassportSecret.changeset(%{status: "burned", burned_at: now()})
    |> Repo.update!()
  end

  defp count_secrets(passport_id, nil) do
    Repo.one(from(s in PassportSecret, where: s.passport_id == ^passport_id, select: count(s.id))) ||
      0
  end

  defp count_secrets(passport_id, status) do
    Repo.one(
      from(s in PassportSecret,
        where: s.passport_id == ^passport_id and s.status == ^status,
        select: count(s.id)
      )
    ) || 0
  end

  defp check_lockout(%Passport{locked_until: nil}), do: :ok

  defp check_lockout(%Passport{locked_until: locked_until}) do
    now = now()

    if DateTime.compare(locked_until, now) == :gt,
      do: {:locked, DateTime.diff(locked_until, now)},
      else: :ok
  end

  defp increment_key_attempts(passport) do
    new_count = passport.key_attempts + 1
    updates = %{key_attempts: new_count}

    updates =
      if new_count >= @key_max_attempts,
        do: Map.put(updates, :locked_until, lock_for(@key_lockout_minutes)),
        else: updates

    passport |> Passport.changeset(updates) |> Repo.update!()
  end

  defp reset_key_attempts(passport) do
    passport |> Passport.changeset(%{key_attempts: 0, locked_until: nil}) |> Repo.update!()
  end

  defp increment_code_attempts(passport) do
    new_count = passport.code_attempts + 1

    if new_count >= @code_max_attempts do
      passport
      |> Passport.changeset(%{
        code_attempts: new_count,
        locked_until: lock_for(@code_lockout_minutes)
      })
      |> Repo.update!()

      {:locked, @code_lockout_minutes * 60}
    else
      passport |> Passport.changeset(%{code_attempts: new_count}) |> Repo.update!()
      :ok
    end
  end

  defp reset_code_attempts(passport) do
    passport |> Passport.changeset(%{code_attempts: 0, locked_until: nil}) |> Repo.update!()
  end

  defp recompute_strength(passport_id), do: passport_strength(passport_id)

  defp update_strength(passport, strength) do
    passport |> Passport.changeset(%{strength: strength}) |> Repo.update!()
  end

  defp get_max_secret_order(passport_id) do
    Repo.one(
      from(s in PassportSecret, where: s.passport_id == ^passport_id, select: max(s.order))
    ) || 0
  end

  defp get_passport_by_handle(handle_code) do
    Repo.one(
      from(p in Passport,
        join: h in PassportHandle,
        on: h.passport_id == p.id,
        where: h.handle_code == ^handle_code and h.status == "active"
      )
    )
  end

  defp changeset_reason(%Ecto.Changeset{errors: errors}) do
    cond do
      Keyword.has_key?(errors, :handle_code) -> :nickname_taken
      Keyword.has_key?(errors, :person_id) -> :already_has_passport
      true -> :invalid
    end
  end

  defp lock_for(minutes), do: DateTime.add(now(), minutes * 60, :second)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
