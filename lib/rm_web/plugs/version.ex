defmodule RMWeb.Version do
  @moduledoc """
  Definition and helpers for versioned API endpoints

  > #### Note {:.info}
  >
  > Versioning APIs can be hard. Our primary objective is to avoid surprising anyone with changes.

  API versions are dates, ex. `"2024-07-01"`. Clients may supply a version header
  `X-RM-API-Version` or rely on the default version saved with the API token they are using. The
  default behaviour is always to leave clients on the version of the API that was available when
  they created their API token, while still providing access to endpoints that were first created
  after that date.

  ## Resolving Versions

  Once we determine the desired API version, we use _the version of the endpoint most recently
  created before the date defined in the version_.

  For example, imagine we have an endpoint with two versions defined:

  * `2024-01-01`: First implementation
  * `2024-07-01`: Revision that returns different data

  If a client requests an API version before the first implementation, such as `2023-10-01`, then
  we optimistically serve the first implementation. Any version between `2024-01-01` and
  `2024-06-30` (the day before the revision), we also serve the first implementation. Any date
  starting `2023-07-01` (the latest revision) or later will use the latest revision.

  ## Introducing a New Version

  We introduce new API versions when a **breaking change** of an existing API endpoint occurs. (It
  is not necessary to define a new version when creating a new endpoint, as older versions will
  always use the first available implementation.)

  Besides implementing the revised endpoint, it is also necessary to add the new version to the
  `@all_versions` module attribute in this module. (This applies to the external API only.) Then,
  make sure to document the changes publicly.

  Not all endpoints will implement every version. The resolution scheme defined above means we
  only need to worry about versioning a specific endpoint when it has breaking changes.
  """

  # Most recent first.
  @all_versions ["2024-07-01"]
  @latest_version List.first(@all_versions)

  @typedoc "Version specification in the form of a date (YYYY-MM-DD) or the default `\"0\"`"
  @type t :: String.t()

  @doc """
  All versions served by the API

  This function must cover all versions served by `ftcregion.com.api`.
  """
  @spec all_versions :: [t]
  def all_versions, do: @all_versions

  @doc """
  Latest version currently served by the **external** API

  This function must cover all versions served by `api.codesandbox.io`. It does not need to cover
  versions used by `codesandbox.io/api`.
  """
  @spec latest_version :: t
  def latest_version, do: @latest_version

  #
  # Plugs
  #

  @doc """
  Match requests with at least the given API version

  The first argument must be a connection struct given as a plain value (ex. `conn`) and the
  second argument must be a valid version string (ex. `"2024-07-01"`).

  This guard was created for use in controller actions that implement multiple versions. Using
  the example from this module's documentation, the controller action function clauses should be
  arranged from newest to oldest:

      # Accept requests with an API version "2024-07-01" or higher
      def action(conn, params) when version(conn, "2024-07-01"), do: ...

      # Accept all other traffic
      def action(conn, params), do: ...

  It is important to have a non-versioned function clause at the end. This ensures clients can
  access newly created endpoints without upgrading to a new API version. If for any reason the
  endpoint cannot be implemented this way, include a non-versioned clause that returns a
  descriptive error instead.

  The provided connection must have a recorded version (via `fetch_version/2`).
  """
  defguard version(conn, version) when conn.assigns.rm_api_version >= version

  @doc """
  Fetch the API version from the request headers and store it on the connection

  In the event a version was not supplied, a default value can be provided using the `:default`
  option. If not supplied, the default is `"0"` representing the earliest version of any endpoint.

  ## Options

    * `default`: Version string to use if no `X-RM-API-Version` header was supplied. Defaults to
      `"0"` representing the earliest version of any endpoint.

  """
  @spec fetch_version(Plug.Conn.t(), keyword) :: Plug.Conn.t()
  def fetch_version(conn, opts) do
    default = opts[:default] || "0"
    version = read_version_header(conn, default)
    Plug.Conn.assign(conn, :rm_api_version, version)
  end

  @spec read_version_header(Plug.Conn.t(), t) :: String.t() | nil
  defp read_version_header(conn, default) do
    case Plug.Conn.get_req_header(conn, "x-rm-api-version") do
      [version | _] -> version
      [] -> default
    end
  end
end
