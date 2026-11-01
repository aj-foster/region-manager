defmodule RM.Util.TimeTest do
  use ExUnit.Case, async: true

  test "returns the friendly name for configured timezones" do
    assert RM.Util.Time.zone_nice_name("America/New_York") == "Eastern US"
  end

  test "preserves the timezone identifier when no friendly name exists" do
    assert RM.Util.Time.zone_nice_name("Asia/Tokyo") == "Asia/Tokyo"
  end

  test "returns a datalist of unique timezone identifiers and readable labels" do
    zones = RM.Util.Time.zones()
    identifiers = Enum.map(zones, &elem(&1, 0))

    assert zones != []
    assert length(identifiers) == MapSet.size(MapSet.new(identifiers))
    assert Enum.all?(zones, fn {zone, label} -> is_binary(zone) and is_binary(label) end)
    assert {"America/New_York", label} = Enum.find(zones, &(elem(&1, 0) == "America/New_York"))
    assert label =~ "Eastern US"
    assert label =~ "GMT"
    assert label =~ ~r/\d{2}:\d{2}$/
  end

  test "filters country timezone options to the configured set" do
    allowed = RM.Util.Location.timezones("Canada")
    zones = RM.Util.Time.zones_for_country("Canada")
    identifiers = Enum.map(zones, &elem(&1, 1))

    assert MapSet.new(identifiers) == MapSet.new(allowed)

    assert Enum.all?(zones, fn {label, zone} ->
             is_binary(zone) and is_binary(label) and label =~ "GMT" and
               label =~ ~r/\d{2}:\d{2}$/
           end)
  end

  test "returns no country timezone options for an unsupported country" do
    assert RM.Util.Time.zones_for_country("Mexico") == []
  end
end
