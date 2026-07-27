ExUnit.start()
# MANUAL, not automatic: each test checks a connection out for itself and gives
# it back at the end, so a test's rows are rolled away and two tests can run at
# the same time without seeing one another.
Ecto.Adapters.SQL.Sandbox.mode(Peoplemedia.Repo, :manual)
