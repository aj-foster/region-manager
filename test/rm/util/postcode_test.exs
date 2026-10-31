defmodule RM.Util.PostcodeTest do
  use ExUnit.Case, async: true

  test "returns coordinates for a postal code" do
    assert RM.Util.Postcode.coordinates("99553") == {54.143, -165.7854}
  end

  test "returns nil for a postal code that is not in the dataset" do
    assert RM.Util.Postcode.coordinates("00000") == nil
  end

  test "uses the first entry when a postal code appears more than once" do
    assert RM.Util.Postcode.coordinates("96860") == {21.316, -157.8677}
  end
end
