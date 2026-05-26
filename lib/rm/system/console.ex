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

  def sync_projects_to_keila do
    RM.FIRST.Region
    |> RM.Repo.all()
    |> Enum.each(fn region ->
      {:ok, _project} = RM.Email.sync_project_for_region(region)
      {:ok, _segment} = region |> RM.Repo.reload!() |> RM.Email.sync_segment_for_region()
      {:ok, _segment} = region |> RM.Repo.reload!() |> RM.Email.sync_coach_segment_for_region()

      region =
        RM.Repo.reload!(region)
        |> RM.Repo.preload(:leagues)

      region.leagues
      |> Enum.each(fn league ->
        {:ok, _segment} = RM.Email.sync_segment_for_league(region, league)
        {:ok, _segment} = RM.Email.sync_coach_segment_for_league(region, league)
      end)
    end)
  end
end
