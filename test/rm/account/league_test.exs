defmodule RM.Account.LeagueTest do
  use ExUnit.Case, async: true

  alias RM.Account.League
  alias RM.Local.League, as: LocalLeague

  describe "create_changeset/2" do
    test "requires an email address" do
      changeset = League.create_changeset(%LocalLeague{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "grants contact, email, and event permissions when user management is enabled" do
      changeset =
        League.create_changeset(%LocalLeague{}, %{
          email: "league-admin@example.com",
          permissions: %{users: true}
        })

      assert changeset.valid?
      permissions = Ecto.Changeset.get_embed(changeset, :permissions)
      assert Ecto.Changeset.get_field(permissions, :contact)
      assert Ecto.Changeset.get_field(permissions, :email)
      assert Ecto.Changeset.get_field(permissions, :events)
      assert Ecto.Changeset.get_field(permissions, :users)
    end

    test "preserves individually selected permissions when user management is disabled" do
      changeset =
        League.create_changeset(%LocalLeague{}, %{
          email: "league-admin@example.com",
          permissions: %{contact: true, email: false, events: true, users: false}
        })

      assert changeset.valid?
      permissions = Ecto.Changeset.get_embed(changeset, :permissions)
      assert Ecto.Changeset.get_field(permissions, :contact)
      refute Ecto.Changeset.get_field(permissions, :email)
      assert Ecto.Changeset.get_field(permissions, :events)
      refute Ecto.Changeset.get_field(permissions, :users)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
