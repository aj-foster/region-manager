defmodule RM.Email do
  @moduledoc """
  Email-related functionality for Region Manager
  """
  alias RM.Email.Address
  alias RM.Email.List
  alias RM.Repo

  #
  # Addresses
  #

  @doc """
  Check if the given email address is known to Region Manager

  This check was added due to a large number of fake sign-ups that sent confirmation emails to
  unsuspecting accounts.
  """
  @spec known_address?(nil) :: false
  @spec known_address?(String.t()) :: boolean
  def known_address?(nil), do: false

  def known_address?(email) do
    email
    |> Address.by_email_query()
    |> Repo.one()
    |> is_nil()
    |> Kernel.not()
  end

  @doc """
  Get an address record by the string address
  """
  @spec get_address(String.t()) :: Address.t() | nil
  def get_address(address_string) do
    address_string
    |> Address.by_email_query()
    |> Repo.one()
  end

  @doc """
  Get an address record by the string address, returning a tagged tuple
  """
  @spec fetch_address(String.t()) :: {:ok, Address.t()} | :error
  def fetch_address(address_string) do
    case get_address(address_string) do
      nil -> :error
      address -> {:ok, address}
    end
  end

  @doc """
  Get an address record by its hashed ID
  """
  @spec get_address_by_hashed_id(String.t()) :: Address.t() | nil
  def get_address_by_hashed_id(hashed_id) do
    Address.by_hashed_id_query(hashed_id)
    |> Repo.one()
  end

  @doc """
  Get an address record by its hashed ID, returning a tagged tuple
  """
  @spec fetch_address_by_hashed_id(String.t()) :: {:ok, Address.t()} | :error
  def fetch_address_by_hashed_id(hashed_id) do
    case get_address_by_hashed_id(hashed_id) do
      nil -> :error
      address -> {:ok, address}
    end
  end

  @doc """
  Mark an email address as bounced or having received a complaint
  """
  @spec mark_email_undeliverable(
          String.t(),
          :complaint | :permanent_bounce | :temporary_bounce | :unsubscribe
        ) :: :ok
  def mark_email_undeliverable(email, :complaint) do
    now = DateTime.utc_now()

    %Address{
      email: email,
      complained_at: now
    }
    |> Repo.insert(
      on_conflict: [
        set: [complained_at: now]
      ],
      conflict_target: [:email]
    )
  end

  def mark_email_undeliverable(email, :permanent_bounce) do
    now = DateTime.utc_now()

    %Address{
      email: email,
      bounce_count: 1,
      first_bounced_at: now,
      last_bounced_at: now,
      permanently_bounced_at: now
    }
    |> Repo.insert(
      on_conflict: [
        set: [last_bounced_at: now, permanently_bounced_at: now],
        inc: [bounce_count: 1]
      ],
      conflict_target: [:email]
    )
  end

  def mark_email_undeliverable(email, :temporary_bounce) do
    now = DateTime.utc_now()

    %Address{
      email: email,
      bounce_count: 1,
      first_bounced_at: now,
      last_bounced_at: now
    }
    |> Repo.insert(
      on_conflict: [
        set: [last_bounced_at: now],
        inc: [bounce_count: 1]
      ],
      conflict_target: [:email]
    )
  end

  def mark_email_undeliverable(email, :unsubscribe) do
    now = DateTime.utc_now()

    %Address{
      email: email,
      unsubscribed_at: now
    }
    |> Repo.insert(
      on_conflict: [
        set: [unsubscribed_at: now]
      ],
      conflict_target: [:email]
    )
  end

  #
  # Lists
  #

  @doc "Create a new email list"
  @spec create_list(map) :: {:ok, List.t()} | {:error, Ecto.Changeset.t(List.t())}
  def create_list(params) do
    List.create_changeset(params)
    |> Repo.insert()
  end
end
