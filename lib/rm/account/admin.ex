defmodule RM.Account.Admin do
  @moduledoc """
  Represents an admin user in the RM system, with extended permissions
  """
  use Ecto.Schema

  alias RM.Account.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_admins" do
    embeds_one :permissions, Permissions, on_replace: :update, primary_key: false do
    end

    belongs_to :user, User

    timestamps type: :utc_datetime_usec
  end
end
