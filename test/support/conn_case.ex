defmodule PeoplemediaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PeoplemediaWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint PeoplemediaWeb.Endpoint

      use PeoplemediaWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PeoplemediaWeb.ConnCase
      import Peoplemedia.Fixtures
    end
  end

  @doc """
  Put a person in the session, the way the token bridge does. The list belongs
  to somebody now, so a test about the list has to say who is looking.
  """
  def check_in(conn, person) do
    Plug.Test.init_test_session(conn, %{"person_id" => person.id})
  end

  setup tags do
    Peoplemedia.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
