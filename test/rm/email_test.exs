defmodule RM.EmailTest do
  use RM.DataCase, async: true

  alias RM.Email
  alias RM.Email.List

  describe "create_list/1" do
    test "creates a list with valid data" do
      params = %{
        "name" => "Test List",
        "description" => "A list for testing",
        "auto_subscribe" => %{
          "admins" => true,
          "coaches" => false,
          "league_admins" => true
        },
        "metadata" => %{
          "subscriber_count" => 10
        }
      }

      assert {:ok, %List{} = list} = Email.create_list(params)
      assert list.name == "Test List"
      assert list.description == "A list for testing"
      assert list.auto_subscribe.admins == true
      assert list.auto_subscribe.coaches == false
      assert list.auto_subscribe.league_admins == true
      assert list.metadata.subscriber_count == 10
    end

    test "fails to create a list with missing required fields" do
      params = %{
        "description" => "Missing name field"
      }

      assert {:error, changeset} = Email.create_list(params)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails to create a list with invalid auto_subscribe data" do
      params = %{
        "name" => "Invalid Auto Subscribe",
        "auto_subscribe" => %{
          # Invalid boolean value
          "admins" => "yes",
          "coaches" => false,
          "league_admins" => true
        }
      }

      assert {:error, changeset} = Email.create_list(params)
      assert %{auto_subscribe: %{admins: ["is invalid"]}} = errors_on(changeset)
    end
  end
end
