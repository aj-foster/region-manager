defmodule RM.FIRST.SeasonTest do
  use RM.DataCase

  alias RM.FIRST.Season

  describe "create_changeset/1" do
    test "derives the season year from kickoff" do
      changeset =
        Season.create_changeset(%{
          kickoff: ~D[2024-09-07],
          logo_url: "https://example.com/logo.png",
          name: "2024–2025 Season",
          year: 1999
        })

      assert changeset.valid?
      assert Ecto.Changeset.apply_changes(changeset).year == 2024
    end

    test "rejects missing required fields, blank names, and non-http logo URLs" do
      changeset =
        Season.create_changeset(%{
          name: "",
          logo_url: "ftp://example.com/logo.png"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).kickoff
      assert "can't be blank" in errors_on(changeset).year
      assert "can't be blank" in errors_on(changeset).name
      assert "has invalid format" in errors_on(changeset).logo_url
    end
  end

  test "serializes the season year as a route parameter" do
    assert Phoenix.Param.to_param(%Season{year: 2024}) == "2024"
  end
end
