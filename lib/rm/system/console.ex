defmodule RM.System.Console do
  @moduledoc false

  def backfill_email_addresses(addresses_string) do
    addresses_string
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.uniq()
    |> Enum.each(fn address ->
      %RM.Email.Address{email: address}
      |> RM.Repo.insert(conflict_target: :email, on_conflict: :nothing)
    end)
  end

  def backfill_bounces(addresses_string) do
    addresses_string
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.uniq()
    |> Enum.each(fn address ->
      RM.Email.mark_email_undeliverable(address, :permanent_bounce)
    end)
  end

  def backfill_unsubscribes(addresses_string) do
    addresses_string
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.uniq()
    |> Enum.each(fn address ->
      RM.Email.mark_email_undeliverable(address, :unsubscribe)
    end)
  end
end
