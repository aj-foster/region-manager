defmodule RMWeb.ConnCase do
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
  by setting `use RMWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """
  alias RM.Factory

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint RMWeb.Endpoint

      use RMWeb, :verified_routes

      alias RM.Factory

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import RM.Assertions
      import RMWeb.ConnCase
    end
  end

  setup tags do
    RM.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Assert response returned from the API is marked with `success: true`

  Returns data for further assertions
  """
  def assert_success(conn, code \\ 200) do
    assert response = Phoenix.ConnTest.json_response(conn, code)
    assert %{"success" => true, "data" => data} = response
    data
  end

  @doc """
  Assert response returned from the API is marked with `success: false`

  Returns errors for further assertions.
  """
  def refute_success(response) do
    assert %{"success" => false, "errors" => errors} = response
    errors
  end

  @doc """
  Create the Florida region
  """
  def create_region(_context) do
    region =
      Factory.insert(:region,
        abbreviation: "FL",
        code: "USFL",
        current_season: 2024,
        description: "Florida, USA",
        has_leagues: true,
        name: "Florida"
      )

    %{region: region}
  end

  @doc """
  Create season records
  """
  def create_seasons(_context) do
    Factory.insert(:season,
      kickoff: ~D[2023-09-09],
      name: "CENTERSTAGE",
      year: 2023
    )

    Factory.insert(:season,
      kickoff: ~D[2024-09-07],
      name: "INTO THE DEEP",
      year: 2024
    )

    :ok
  end
end
