defmodule RM.Util.StructTest do
  use ExUnit.Case, async: true

  alias RM.Util.Struct

  describe "extract_id/2" do
    test "returns nil for nil input" do
      assert Struct.extract_id(nil) == nil
    end

    test "returns a binary ID unchanged" do
      id = Ecto.UUID.generate()

      assert Struct.extract_id(id) == id
    end

    test "extracts the ID field from a struct" do
      user = %RM.Account.User{id: Ecto.UUID.generate()}

      assert Struct.extract_id(user) == user.id
    end

    test "extracts a specified field from a struct" do
      uri = %URI{host: "example.com"}

      assert Struct.extract_id(uri, :host) == "example.com"
    end
  end

  describe "extract_ids/2" do
    test "returns an empty list for nil input" do
      assert Struct.extract_ids(nil) == []
    end

    test "wraps a single ID in a list" do
      id = Ecto.UUID.generate()

      assert Struct.extract_ids(id) == [id]
    end

    test "extracts IDs from a list of structs and IDs" do
      id = Ecto.UUID.generate()
      user = %RM.Account.User{id: Ecto.UUID.generate()}

      assert Struct.extract_ids([user, id]) == [user.id, id]
    end

    test "extracts a specified field from each struct" do
      uris = [%URI{host: "one.example"}, %URI{host: "two.example"}]

      assert Struct.extract_ids(uris, :host) == ["one.example", "two.example"]
    end
  end
end
