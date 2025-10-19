defmodule RM.Email.Address do
  @moduledoc """
  Record of an email address known to Region Manager

  This record, and the corresponding protections that use it, was added in response to a large
  number of fake user registrations that caused email confirmations to be sent as spam. While we
  obviously don't want to contribute spam to the world, we also need to protect the sending
  reputation of this application.

  This record also tracks if a known email address starts to bounce messages.
  """
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset

  @typedoc "Email address known to Region Manager"
  @type t :: %__MODULE__{
          bounce_count: integer,
          email: String.t(),
          first_bounced_at: DateTime.t() | nil,
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          last_bounced_at: DateTime.t() | nil,
          permanently_bounced_at: DateTime.t() | nil,
          sendable: boolean,
          unsubscribed_at: DateTime.t() | nil,
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "email_addresses" do
    field :email, :string

    field :bounce_count, :integer
    field :complained_at, :utc_datetime_usec
    field :first_bounced_at, :utc_datetime_usec
    field :last_bounced_at, :utc_datetime_usec
    field :permanently_bounced_at, :utc_datetime_usec
    field :unsubscribed_at, :utc_datetime_usec

    # Generated columns (read-only)
    field :hashed_id, :string, read_after_writes: true
    field :sendable, :boolean, read_after_writes: true

    timestamps type: :utc_datetime_usec
  end

  #
  # Changesets
  #

  @doc """
  Prepare one changeset or many parameter maps with new email address records
  """
  @spec new([String.t()]) :: [map]
  def new(emails) when is_list(emails) do
    now = DateTime.utc_now()

    for email <- emails do
      %{email: String.downcase(email), inserted_at: now, updated_at: now}
    end
  end

  @spec new(String.t()) :: Changeset.t(t)
  def new(email) do
    %__MODULE__{}
    |> Changeset.change(email: String.downcase(email))
  end

  #
  # Queries
  #

  @doc """
  Query to find an email record by the address
  """
  @spec by_email_query(String.t()) :: Ecto.Query.t()
  def by_email_query(email) do
    from(__MODULE__, as: :email)
    |> where([email: e], e.email == ^email)
  end

  @doc """
  Query to find an email record by the address
  """
  @spec by_hashed_id_query(String.t()) :: Ecto.Query.t()
  def by_hashed_id_query(hashed_id) do
    from(__MODULE__, as: :email)
    |> where([email: e], e.hashed_id == ^hashed_id)
  end
end
