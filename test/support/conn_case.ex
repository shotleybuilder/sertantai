defmodule SertantaiWeb.ConnCase do
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
  by setting `use SertantaiWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint SertantaiWeb.Endpoint

      use SertantaiWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import SertantaiWeb.ConnCase
    end
  end

  setup tags do
    Sertantai.DataCase.setup_sandbox(tags)
    
    # Set up connection
    conn = Phoenix.ConnTest.build_conn()
    
    # Register cleanup callback to ensure LiveView processes are terminated
    on_exit(fn ->
      # Force garbage collection to clean up any lingering processes
      :erlang.garbage_collect()
    end)
    
    {:ok, conn: conn}
  end

  @doc """
  Setup helper that logs in a user for testing authenticated routes.
  Uses AshAuthentication.Phoenix to properly store user in session.
  """
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
