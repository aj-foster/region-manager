defmodule RM.Util.LocationTest do
  use ExUnit.Case, async: true

  test "returns supported countries in alphabetical order" do
    assert RM.Util.Location.countries() == ["Canada", "United States"]
  end

  test "returns configured published country abbreviations" do
    assert RM.Util.Location.published_abbreviation("United States") == "USA"
    assert RM.Util.Location.published_abbreviation("Canada") == nil
    assert RM.Util.Location.published_abbreviation("Mexico") == nil
    assert RM.Util.Location.published_abbreviation(nil) == nil
  end

  test "returns full names and abbreviations, including source-specific spellings" do
    assert {"Québec", "QC"} in RM.Util.Location.state_provinces("Canada")
    assert {"Newfoundland and Labrador", "NL"} in RM.Util.Location.state_provinces("Canada")
    assert {"Armed Forces - Americas", "AA"} in RM.Util.Location.state_provinces("United States")
    assert {"California", "CA"} in RM.Util.Location.state_provinces("United States")
    assert {"Northern Mariana Islands", "MP"} in RM.Util.Location.state_provinces("United States")

    assert {"United States Minor Outlying Islands", "UM"} in RM.Util.Location.state_provinces(
             "United States"
           )
  end

  test "each supported state or province has a unique name and two-letter abbreviation" do
    for country <- RM.Util.Location.countries() do
      entries = RM.Util.Location.state_provinces(country)
      names = Enum.map(entries, &elem(&1, 0))
      abbreviations = Enum.map(entries, &elem(&1, 1))

      assert length(names) == length(Enum.uniq(names))
      assert length(abbreviations) == length(Enum.uniq(abbreviations))
      assert Enum.all?(abbreviations, &Regex.match?(~r/^[A-Z]{2}$/, &1))
    end
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
