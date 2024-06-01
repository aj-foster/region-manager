defmodule RM.Local do
  @moduledoc """
  Entrypoint for team and league data management
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.FIRST.League
  alias RM.Local.EventRegistration
  alias RM.Local.EventSettings
  alias RM.Local.LeagueSettings
  alias RM.Local.RegistrationSettings
  alias RM.Local.Query
  alias RM.Local.Team
  alias RM.Repo

  @spec list_teams_by_number([integer], keyword) :: [Team.t()]
  def list_teams_by_number(numbers, opts \\ []) do
    Query.from_team()
    |> where([team: t], t.number in ^numbers)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.all()
  end

  @spec list_teams_by_team_id([integer], keyword) :: [Team.t()]
  def list_teams_by_team_id(team_ids, opts \\ []) do
    Query.from_team()
    |> where([team: t], t.team_id in ^team_ids)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.all()
  end

  @spec fetch_team_by_number(integer) :: {:ok, Team.t()} | {:error, :team, :not_found}
  def fetch_team_by_number(team_number, opts \\ []) do
    Query.from_team()
    |> where([team: t], t.number == ^team_number)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.one()
    |> case do
      %Team{} = team -> {:ok, team}
      nil -> {:error, :team, :not_found}
    end
  end

  @spec verify_eligibility(Event.t(), Team.t()) ::
          :ok | {:error, :not_event_ready | :out_of_scope | :deadline_passed}
  def verify_eligibility(event, team)

  def verify_eligibility(%Event{type: type}, %Team{event_ready: false})
      when type in [
             :league_meet,
             :qualifier,
             :league_tournament,
             :regional_championship,
             :championship,
             :super_qualifier
           ],
      do: {:error, :not_event_ready}

  def verify_eligibility(
        %Event{
          league_id: event_league_id,
          settings: %EventSettings{registration: %RegistrationSettings{pool: :league}}
        },
        %Team{league: %League{id: team_league_id}}
      )
      when event_league_id != team_league_id,
      do: {:error, :out_of_scope}

  def verify_eligibility(
        %Event{
          region_id: event_region_id,
          settings: %EventSettings{registration: %RegistrationSettings{pool: :region}}
        },
        %Team{region_id: team_region_id}
      )
      when event_region_id != team_region_id,
      do: {:error, :out_of_scope}

  def verify_eligibility(event, _team) do
    if Event.registration_deadline_passed?(event) do
      {:error, :deadline_passed}
    else
      :ok
    end
  end

  @spec create_event_registration(Event.t(), Team.t(), map) ::
          {:ok, EventRegistration.t()} | {:error, Changeset.t(EventRegistration.t())}
  def create_event_registration(event, team, params) do
    EventRegistration.create_changeset(event, team, params)
    |> Repo.insert()
  end

  @spec update_event_registration(EventRegistration.t(), map) ::
          {:ok, EventRegistration.t()} | {:error, Changeset.t(EventRegistration.t())}
  def update_event_registration(registration, params) do
    EventRegistration.update_changeset(registration, params)
    |> Repo.update()
  end

  @spec change_event_settings(Event.t()) :: Changeset.t(EventSettings.t())
  def change_event_settings(event) do
    case Repo.preload(event, :settings) do
      %Event{settings: nil} ->
        EventSettings.changeset(%{})
        |> Changeset.put_assoc(:event, event)

      %Event{settings: settings} ->
        EventSettings.changeset(settings, %{})
    end
  end

  @spec update_event_settings(Event.t(), map) ::
          {:ok, EventSettings.t()} | {:error, Changeset.t(EventSettings.t())}
  def update_event_settings(event, params) do
    case Repo.preload(event, :settings) do
      %Event{settings: nil} ->
        %EventSettings{registration: %RegistrationSettings{enabled: true, pool: :event}}
        |> EventSettings.changeset(params)
        |> Changeset.put_assoc(:event, event)
        |> Repo.insert()

      %Event{settings: settings} ->
        EventSettings.changeset(settings, params)
        |> Repo.update()
    end
  end

  @spec change_league_settings(League.t()) :: Changeset.t(LeagueSettings.t())
  def change_league_settings(league) do
    case Repo.preload(league, :settings) do
      %League{settings: nil} ->
        LeagueSettings.changeset(%{})
        |> Changeset.put_assoc(:league, league)

      %League{settings: settings} ->
        LeagueSettings.changeset(settings, %{})
    end
  end

  @spec update_league_settings(League.t(), map) ::
          {:ok, LeagueSettings.t()} | {:error, Changeset.t(LeagueSettings.t())}
  def update_league_settings(league, params) do
    case Repo.preload(league, :settings) do
      %League{settings: nil} ->
        %LeagueSettings{registration: %RegistrationSettings{enabled: true, pool: :league}}
        |> LeagueSettings.changeset(params)
        |> Changeset.put_assoc(:league, league)
        |> Repo.insert()

      %League{settings: settings} ->
        LeagueSettings.changeset(settings, params)
        |> Repo.update()
    end
  end
end
