defmodule RM.Util.LocationTest do
  use ExUnit.Case, async: true

  test "returns supported countries in alphabetical order" do
    assert RM.Util.Location.countries() == ["Canada", "United States"]
  end

  test "returns the supported provinces including source-specific spellings" do
    assert "Québec" in RM.Util.Location.state_provinces("Canada")
    assert "Armed Forces - Americas" in RM.Util.Location.state_provinces("United States")
  end

  test "returns an empty province list for an unsupported country" do
    assert RM.Util.Location.state_provinces("Mexico") == []
  end

  test "requires a state or province only for supported countries" do
    assert RM.Util.Location.state_province_required?("Canada")
    assert RM.Util.Location.state_province_required?("United States")
    refute RM.Util.Location.state_province_required?("Mexico")
  end

  test "returns the configured country timezones" do
    assert "America/St_Johns" in RM.Util.Location.timezones("Canada")
    assert "Pacific/Honolulu" in RM.Util.Location.timezones("United States")
  end

  test "returns no timezones for an unsupported country" do
    assert RM.Util.Location.timezones("Mexico") == []
  end
end
