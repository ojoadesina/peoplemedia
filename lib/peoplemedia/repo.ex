defmodule Peoplemedia.Repo do
  use Ecto.Repo,
    otp_app: :peoplemedia,
    adapter: Ecto.Adapters.Postgres
end
