import Config

# Each test runs in its own transaction and is rolled back, so tests never see
# one another's rows and can run concurrently.
config :peoplemedia, Peoplemedia.Repo,
  username: System.get_env("PGUSER") || "postgres",
  password: System.get_env("PGPASSWORD") || "postgres",
  hostname: "localhost",
  database: "peoplemedia_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# BCRYPT AT ITS CHEAPEST IN TEST, and only in test. The passport hashes a code
# and every word in the bank, so one sign-up is a dozen hashes; at production
# cost the identity suite spends real seconds proving bcrypt works, which is
# bcrypt's job and not ours. Identity passes its rounds explicitly, so the
# global setting alone would not have reached it.
config :bcrypt_elixir, log_rounds: 4
config :peoplemedia, bcrypt_secret_rounds: 4, bcrypt_code_rounds: 4

# THE MASTER-HANDLE EXEMPTION IS ON IN TESTS, under a handle no fixture uses, so
# that both halves are proved on every run: that this one passport's words are
# not spent, and that everybody else's still are. A hole in the login path that
# only exists in dev and prod is a hole nothing tests.
config :peoplemedia, master_handle: "master"

# NO OUTBOUND CALLS FROM A TEST RUN. The country step reverse-geocodes, and the
# real geocoder is a public service run by volunteers — a suite that called it on
# every run would be slow, would fail on a train, and would be a poor guest.
config :peoplemedia, geocoder: Peoplemedia.Geo.Stub

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :peoplemedia, PeoplemediaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "GgfmUb6cr9bJivITwg5yLw/kAppzPSSVTQgqL3kKkITeDSY17Yu8rM/6/hN5trgf",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
