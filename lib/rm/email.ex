defmodule RM.Email do
  @moduledoc """
  Email-related functionality for Region Manager
  """
  alias RM.Email.Address
  alias RM.Repo

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

  @doc """
  Check if the given email address is known to Region Manager

  This check was added due to a large number of fake sign-ups that sent confirmation emails to
  unsuspecting accounts.
  """
  @spec known_email?(nil) :: false
  @spec known_email?(String.t()) :: boolean
  def known_email?(nil), do: false

  def known_email?(email) do
    email
    |> Address.by_email_query()
    |> Repo.one()
    |> is_nil()
    |> Kernel.not()
  end
end
