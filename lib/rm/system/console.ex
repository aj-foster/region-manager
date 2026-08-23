defmodule RM.System.Console do
  @moduledoc false
  import Ecto.Query

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

  def backfill_confirmed_email_addresses do
    from(Identity.Schema.Email, as: :email)
    |> where([email: e], not is_nil(e.confirmed_at))
    |> select([email: e], e.email)
    |> RM.Repo.all()
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
    unless Keila.Repo.get_by(Keila.Auth.Group, name: "root") do
      Keila.Repo.insert!(%Keila.Auth.Group{name: "root"})
    end

    RM.FIRST.Region
    |> RM.Repo.all()
    |> Enum.each(fn region ->
      {:ok, _project} = RM.Email.sync_project_for_region(region)
      region = RM.Repo.reload!(region)
      {:ok, _segment} = RM.Email.sync_segment_for_region(region)
      {:ok, _segment} = RM.Email.sync_coach_segment_for_region(region)
      {:ok, _segment} = RM.Email.sync_extended_coach_segment_for_region(region)
      :ok = RM.Email.sync_template_for_region(region)
      :ok = RM.Email.sync_shared_sender_for_region(region)
      :ok = RM.Email.sync_sender_for_region(region)

      region =
        RM.Repo.reload!(region)
        |> RM.Repo.preload(:leagues)

      region.leagues
      |> Enum.each(fn league ->
        {:ok, _segment} = RM.Email.sync_segment_for_league(region, league)
        {:ok, _segment} = RM.Email.sync_coach_segment_for_league(region, league)
        {:ok, _segment} = RM.Email.sync_extended_coach_segment_for_league(region, league)
        :ok = RM.Email.sync_sender_for_league(region, league)
      end)

      region
      |> RM.Local.list_teams_by_region()
      |> Enum.each(fn team ->
        RM.Email.sync_coach_contacts_for_team(team)
      end)
    end)
  end
end
