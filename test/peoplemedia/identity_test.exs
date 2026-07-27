defmodule Peoplemedia.IdentityTest do
  @moduledoc """
  THE PASSPORT, PROVEN. This is ported code, and porting is exactly where auth
  quietly breaks: a rename that compiles can still hash the wrong field, burn the
  wrong row, or hand back a person who never checked in. Nothing here tests
  bcrypt — it tests that the two-step check-in is wired to the right columns and
  that its guards actually guard.
  """
  use Peoplemedia.DataCase, async: true

  alias Peoplemedia.{Identity, People}
  alias Peoplemedia.Identity.{Passport, PassportSecret}

  @words ~w(harbour lantern thistle)
  @code "4417"

  defp person(name \\ "Sarah") do
    {:ok, person} = People.create_person(%{name: name, country: "Finland"})
    person
  end

  defp passported(handle \\ "sarah") do
    p = person()
    {:ok, passport} = Identity.create_passport(p, handle, @words, @code)
    {p, passport}
  end

  describe "create_passport/4" do
    test "claims the handle, banks the words and stores nothing in the clear" do
      p = person()
      assert {:ok, %Passport{} = passport} = Identity.create_passport(p, "sarah", @words, @code)
      assert passport.person_id == p.id

      # THE CODE IS HASHED, and the handle is normalised for lookup.
      refute passport.code_hash == @code
      assert Identity.get_passport(p.id)

      # EVERY WORD IS HASHED TOO. A word bank kept in the clear would make the
      # one-time scheme pointless — the whole bank leaks with one query.
      secrets = Repo.all(PassportSecret)
      assert length(secrets) == 3
      for s <- secrets, do: refute(s.secret_hash in @words)
      assert Enum.all?(secrets, &(&1.status == "active"))
    end

    test "a handle can only be claimed once, whatever its case" do
      {_p, _} = passported("sarah")

      assert {:error, :nickname_taken} =
               Identity.create_passport(person(), "SARAH", @words, @code)
    end

    test "refuses a bank too small to survive its own use" do
      assert {:error, :too_few_secrets} =
               Identity.create_passport(person(), "amina", ~w(harbour lantern), @code)
    end

    test "refuses a code that is not four digits" do
      assert {:error, :invalid_code_format} =
               Identity.create_passport(person(), "amina", @words, "441")
    end

    test "refuses duplicate words — a bank of the same word is a bank of one" do
      assert {:error, :duplicate_secrets} =
               Identity.create_passport(person(), "amina", ~w(harbour harbour thistle), @code)
    end
  end

  describe "check-in" do
    test "word then code, and the word burns only when both are right" do
      {p, passport} = passported()

      assert {:ok, ^passport, secret_id} = Identity.check_key("sarah", "harbour")
      # STILL ACTIVE. A word survives a wrong code, or a wrong guess at step two
      # would spend a word on someone who never got in.
      assert Repo.get!(PassportSecret, secret_id).status == "active"

      assert {:error, :wrong_code} = Identity.check_code(passport, "0000", secret_id)
      assert Repo.get!(PassportSecret, secret_id).status == "active"

      assert {:ok, signed_in} = Identity.check_code(passport, @code, secret_id)
      assert signed_in.id == p.id
      assert Repo.get!(PassportSecret, secret_id).status == "burned"
    end

    test "a burned word cannot be used again" do
      {_p, passport} = passported()
      {:ok, _, secret_id} = Identity.check_key("sarah", "harbour")
      {:ok, _} = Identity.check_code(passport, @code, secret_id)

      assert {:error, :invalid_credentials} = Identity.check_key("sarah", "harbour")
    end

    test "an unknown handle answers exactly like a wrong word" do
      {_p, _} = passported()
      assert {:error, :invalid_credentials} = Identity.check_key("nobody", "harbour")
      assert {:error, :invalid_credentials} = Identity.check_key("sarah", "wrongword")
    end

    test "repeated wrong words lock the passport" do
      {_p, _} = passported()

      # Five failures arm the lock; the sixth attempt meets it — and meets it
      # even with the RIGHT word, which is the point of a lockout.
      for _ <- 1..5,
          do: assert({:error, :invalid_credentials} = Identity.check_key("sarah", "no"))

      assert {:error, :locked, seconds} = Identity.check_key("sarah", "harbour")
      assert seconds > 0
    end

    test "repeated wrong codes lock it too, on their own counter" do
      {_p, _} = passported()
      {:ok, passport, secret_id} = Identity.check_key("sarah", "harbour")

      assert {:error, :wrong_code} = Identity.check_code(passport, "0000", secret_id)
      passport = Repo.get!(Passport, passport.id)
      assert {:error, :wrong_code} = Identity.check_code(passport, "0001", secret_id)
      passport = Repo.get!(Passport, passport.id)
      assert {:error, :locked, _} = Identity.check_code(passport, "0002", secret_id)

      # And the word is still unspent — it was never matched against a right code.
      assert Repo.get!(PassportSecret, secret_id).status == "active"
    end
  end

  describe "strength" do
    test "falls as words burn and rises again on a top-up" do
      {p, passport} = passported()
      assert Identity.passport_strength(passport.id) == 100

      {:ok, passport, secret_id} = Identity.check_key("sarah", "harbour")
      {:ok, _} = Identity.check_code(passport, @code, secret_id)

      # Two of three left.
      assert Identity.passport_strength(passport.id) == 67
      assert Identity.get_passport(p.id).strength == 67

      {:ok, _} = Identity.add_secrets(Repo.get!(Passport, passport.id), ~w(meadow copper))
      # Four of five.
      assert Identity.passport_strength(passport.id) == 80
    end

    test "asks for a top-up only once the bank is genuinely low" do
      refute Identity.needs_renewal?(%Passport{strength: 100})
      refute Identity.needs_renewal?(%Passport{strength: 40})
      assert Identity.needs_renewal?(%Passport{strength: 39})
    end
  end

  describe "handle_available?/1" do
    test "free, taken, and malformed" do
      assert Identity.handle_available?("amina")
      {_p, _} = passported("sarah")
      refute Identity.handle_available?("sarah")
      refute Identity.handle_available?("SARAH")
      # Too long, and punctuation is not a handle.
      refute Identity.handle_available?("waytoolongahandle")
      refute Identity.handle_available?("sa rah")
    end
  end
end
