defmodule RMWeb.VersionTest do
  use ExUnit.Case, async: true

  alias RMWeb.Version
  require Version

  test "exposes the latest supported API version" do
    assert Version.all_versions() == ["2024-07-01"]
    assert Version.latest_version() == "2024-07-01"
  end

  test "assigns the earliest version by default when the header is absent" do
    conn = Version.fetch_version(Plug.Test.conn(:get, "/"), [])

    assert conn.assigns.rm_api_version == "0"
    refute Version.version(conn, "2024-07-01")
  end

  test "uses the configured default when the header is absent" do
    conn = Plug.Test.conn(:get, "/") |> Version.fetch_version(default: "2024-07-01")

    assert conn.assigns.rm_api_version == "2024-07-01"
    assert Version.version(conn, "2024-07-01")
  end

  test "uses the first API version header when multiple are present" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Conn.prepend_req_headers([
        {"x-rm-api-version", "2024-07-01"},
        {"x-rm-api-version", "2020-01-01"}
      ])
      |> Version.fetch_version([])

    assert conn.assigns.rm_api_version == "2024-07-01"
    assert Version.version(conn, "2024-01-01")
  end
end
