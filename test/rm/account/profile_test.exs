defmodule RM.Account.ProfileTest do
  use ExUnit.Case, async: true

  alias RM.Account.Profile
  alias RM.Account.User

  describe "create_changeset/2" do
    test "requires a name" do
      changeset = Profile.create_changeset(%{}, %User{id: Ecto.UUID.generate()})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "associates the user and casts the profile name" do
      user = %User{id: Ecto.UUID.generate()}
      changeset = Profile.create_changeset(%{"name" => "Taylor"}, user)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :name) == "Taylor"
      assert Ecto.Changeset.get_assoc(changeset, :user).data.id == user.id
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
