defmodule RM.Import do
  require NimbleCSV

  alias RM.Account
  alias RM.FIRST.Region
  alias RM.Import.Team
  alias RM.Import.Upload
  alias RM.Local
  alias RM.Repo

  NimbleCSV.define(RM.Import.TeamDataParser,
    separator: "\t",
    escape: "\"",
    encoding: :utf8,
    trim_bom: true,
    dump_bom: true
  )

  @spec import_from_team_info_tableau_export(Account.User.t(), String.t()) :: term
  def import_from_team_info_tableau_export(user, path_to_file) do
    %Upload{id: upload_id} = upload = insert_import_upload(user, path_to_file)

    allowed_regions = Account.get_regions_for_user(user)
    allowed_region_names = Enum.map(allowed_regions, & &1.name)
    allowed_regions_by_name = Map.new(allowed_regions, fn region -> {region.name, region} end)

    stream =
      path_to_file
      |> File.stream!([:trim_bom, encoding: {:utf16, :little}])
      |> RM.Import.TeamDataParser.parse_stream(skip_headers: false)

    [header] =
      stream
      |> Stream.take(1)
      |> Enum.to_list()

    {_count, import_teams} =
      stream
      |> Stream.drop(1)
      |> Stream.map(&Enum.zip(header, &1))
      |> Stream.map(&Map.new/1)
      |> Stream.filter(fn %{"Active Team" => status} -> status == "Active" end)
      |> Stream.filter(fn %{"Secured Status" => secured, "Intent To Return" => intent} ->
        secured == "Secured" or intent == "1"
      end)
      |> Stream.filter(fn %{"Region Name" => region} -> region in allowed_region_names end)
      |> Stream.map(&Team.from_csv/1)
      |> Stream.map(&Team.put_region(&1, allowed_regions_by_name[&1.region].id))
      |> Stream.map(&Team.put_upload(&1, upload_id))
      |> Enum.to_list()
      |> insert_import_teams()

    local_teams_by_id = list_local_teams(import_teams)
    import_teams_by_id = Map.new(import_teams, fn team -> {team.team_id, team} end)

    {additions, updates} = diff_teams(local_teams_by_id, import_teams_by_id)
    update_region_counts(import_teams)
    relink_coaches(import_teams, additions ++ Enum.map(updates, &elem(&1, 0)))

    %{added: additions, updated: updates, imported: import_teams, upload: upload}
  end

  @spec insert_import_upload(Account.User.t(), String.t()) :: Upload.t()
  defp insert_import_upload(user, path_to_file) do
    Upload.new(user, path_to_file)
    |> Repo.insert!()
  end

  @spec insert_import_teams([Team.t()]) :: {integer, [Team.t()]}
  defp insert_import_teams(teams) do
    teams = Enum.map(teams, &prepare_import_team_for_insert/1)
    Repo.insert_all(Team, teams, returning: true)
  end

  @spec prepare_import_team_for_insert(Team.t()) :: map
  defp prepare_import_team_for_insert(team) do
    team
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.put(:id, Ecto.UUID.generate())
  end

  @spec list_local_teams([Team.t()]) :: %{integer => Local.Team.t()}
  defp list_local_teams(import_teams) do
    import_teams
    |> Enum.map(& &1.team_id)
    |> Local.list_teams_by_team_id(preload: [:users])
    |> Map.new(fn team -> {team.team_id, team} end)
  end

  @spec diff_teams(%{integer => Local.Team.t()}, %{integer => Team.t()}) ::
          {[Local.Team.t()], [{Local.Team.t(), Ecto.Changeset.t(Local.Team.t())}]}
  defp diff_teams(local_teams_by_id, import_teams_by_id) do
    {import_overlapping, import_to_add} =
      Map.split(import_teams_by_id, Map.keys(local_teams_by_id))

    additions =
      for import_team <- Map.values(import_to_add) do
        %Local.Team{}
        |> Local.Team.from_import(import_team)
        |> Repo.insert!()
      end

    updates =
      for import_team <- Map.values(import_overlapping) do
        changeset =
          local_teams_by_id[import_team.team_id]
          |> Local.Team.from_import(import_team)

        team = Repo.update!(changeset)
        {team, changeset}
      end

    {additions, updates}
  end

  @spec update_region_counts([Team.t()]) :: {integer, nil}
  defp update_region_counts(import_teams) do
    import_teams
    |> Enum.map(& &1.region_id)
    |> Enum.uniq()
    |> Region.team_stats_update_query()
    |> Repo.update_all([])
  end

  @spec relink_coaches([Team.t()], [Local.Team.t()]) :: {integer, integer}
  defp relink_coaches(import_teams, local_teams) do
    team_id_map = Map.new(local_teams, fn team -> {team.team_id, team.id} end)

    user_teams =
      import_teams
      |> Enum.map(&Account.Team.from_import(&1, team_id_map))
      |> List.flatten()
      |> Enum.map(&prepare_user_team_for_insert/1)

    {coaches_count, coaches} =
      Repo.insert_all(Account.Team, user_teams,
        on_conflict: :replace_all,
        conflict_target: [:team_id, :relationship],
        returning: [:id]
      )

    {coaches_linked_count, _nil} =
      coaches
      |> Enum.map(& &1.id)
      |> Account.Team.user_update_query()
      |> Repo.update_all([])

    {coaches_count, coaches_linked_count}
  end

  @spec prepare_user_team_for_insert(Account.Team.t()) :: map
  defp prepare_user_team_for_insert(user_team) do
    user_team
    |> Map.from_struct()
    |> Map.drop([:__meta__, :team, :user])
    |> Map.put(:id, Ecto.UUID.generate())
  end
end
