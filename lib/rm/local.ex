defmodule RM.Local do
  @moduledoc """
  Entrypoint for team and league data management
  """
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.FIRST.Region
  alias RM.Local.EventProposal
  alias RM.Local.EventRegistration
  alias RM.Local.EventSettings
  alias RM.Local.League
  alias RM.Local.LeagueSettings
  alias RM.Local.RegistrationSettings
  alias RM.Local.Query
  alias RM.Local.Team
  alias RM.Local.Venue
  alias RM.Repo

  #
  # Events
  #

  @spec list_registered_events_by_team(Team.t()) :: [EventRegistration.t()]
  @spec list_registered_events_by_team(Team.t(), keyword) :: [EventRegistration.t()]
  def list_registered_events_by_team(team, opts \\ []) do
    Query.from_registration()
    |> where([registration: r], r.team_id == ^team.id)
    |> Query.rescinded(opts[:rescinded])
    |> Query.waitlisted(opts[:waitlisted])
    |> Query.preload_assoc(:registration, [:event])
    |> Query.preload_assoc(:registration, opts[:preload])
    |> Repo.all()
    |> Enum.sort_by(& &1.event, Event)
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

  #
  # Event Proposals
  #

  @spec list_event_proposals_by_region(RM.FIRST.Region.t()) :: [EventProposal.t()]
  @spec list_event_proposals_by_region(RM.FIRST.Region.t(), keyword) :: [EventProposal.t()]
  def list_event_proposals_by_region(region, opts \\ []) do
    %RM.FIRST.Region{current_season: season} = region

    Query.from_proposal()
    |> Query.proposal_region(region)
    |> Query.proposal_season(season)
    |> Query.preload_assoc(:proposal, opts[:preload])
    |> Repo.all()
    |> Enum.sort(EventProposal)
    |> Enum.map(fn
      %EventProposal{region: %RM.FIRST.Region{}} = proposal -> proposal
      proposal -> %EventProposal{proposal | region: region}
    end)
  end

  @spec fetch_event_proposal_by_id(Ecto.UUID.t()) ::
          {:ok, EventProposal.t()} | {:error, :proposal, :not_found}
  @spec fetch_event_proposal_by_id(Ecto.UUID.t(), keyword) ::
          {:ok, EventProposal.t()} | {:error, :proposal, :not_found}
  def fetch_event_proposal_by_id(proposal_id, opts \\ []) do
    Query.from_proposal()
    |> Query.league(opts[:league])
    |> Query.preload_assoc(:proposal, opts[:preload])
    |> Repo.get(proposal_id)
    |> case do
      %EventProposal{} = proposal -> {:ok, proposal}
      nil -> {:error, :proposal, :not_found}
    end
  end

  @spec create_event(map) :: {:ok, EventProposal.t()} | {:error, Changeset.t(EventProposal.t())}
  def create_event(params) do
    EventProposal.create_changeset(params)
    |> Repo.insert()
  end

  @spec create_batch_submission(Region.t(), [EventProposal.t()], RM.Account.User.t()) ::
          {:ok, String.t()} | {:error, any}
  def create_batch_submission(region, proposals, user) do
    id = Ecto.UUID.generate()
    params = %{event_count: length(proposals), id: id, generated_by: user.id, region: region}

    with {:ok, {_name, file_contents}} <- RM.Local.EventBatch.new(region, proposals, id: id),
         changeset <- RM.Local.EventBatch.save(file_contents, params),
         {:ok, event_batch} <- Repo.insert(changeset) do
      EventProposal.update_submitted_at_query(proposals)
      |> Repo.update_all([])

      url = RM.Local.EventSubmission.url({"", event_batch}, signed: true)
      {:ok, url}
    end
  end

  @spec list_batch_submissions(Region.t()) :: [RM.Local.EventBatch.t()]
  @spec list_batch_submissions(Region.t(), keyword) :: [RM.Local.EventBatch.t()]
  def list_batch_submissions(region, opts \\ []) do
    from(RM.Local.EventBatch, as: :batch)
    |> where([batch: b], b.region_id == ^region.id)
    |> order_by([batch: b], desc: b.generated_at)
    |> Query.paginate(opts[:per_page], opts[:page])
    |> Repo.all()
  end

  #
  # Event Registration
  #

  @spec fetch_event_registration(Event.t(), Team.t()) ::
          {:ok, EventRegistration.t()} | {:error, :registration, :not_found}
  def fetch_event_registration(event, team) do
    Query.from_registration()
    |> where([registration: r], r.event_id == ^event.id and r.team_id == ^team.id)
    |> Repo.one()
    |> case do
      %EventRegistration{} = registration -> {:ok, registration}
      nil -> {:error, :registration, :not_found}
    end
  end

  @spec create_event_registration(Event.t(), Team.t(), map) ::
          {:ok, EventRegistration.t()} | {:error, Changeset.t(EventRegistration.t())}
  def create_event_registration(event, team, params) do
    EventRegistration.create_changeset(event, team, params)
    |> Repo.insert()
  end

  @spec rescind_event_registration(EventRegistration.t(), map) ::
          {:ok, EventRegistration.t()} | {:error, Changeset.t(EventRegistration.t())}
  def rescind_event_registration(registration, params) do
    EventRegistration.rescind_changeset(registration, params)
    |> Repo.update()
  end

  #
  # Leagues
  #

  @spec fetch_league_by_code(String.t(), String.t(), keyword) ::
          {:ok, League.t()} | {:error, :league, :not_found}
  def fetch_league_by_code(region_abbr, code, opts \\ []) do
    Query.from_league()
    |> Query.preload_assoc(:league, [:region])
    |> RM.FIRST.Query.region_abbreviation(region_abbr)
    |> Query.league_code(code)
    |> Query.preload_assoc(:league, opts[:preload])
    |> Repo.one()
    |> case do
      %League{} = league -> {:ok, league}
      nil -> {:error, :league, :not_found}
    end
  end

  @spec create_leagues_from_first(Region.t()) :: [RM.Local.League.t()]
  @spec create_leagues_from_first(Region.t(), keyword) :: [RM.Local.League.t()]
  def create_leagues_from_first(region, opts \\ []) do
    # First round: Initial insertion of the records

    first_leagues = RM.FIRST.list_leagues_by_region(region, opts)
    league_data = Enum.map(first_leagues, &RM.Local.League.from_first_league/1)

    leagues =
      Repo.insert_all(RM.Local.League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:code, :region_id],
        returning: true
      )
      |> elem(1)

    league_settings_data = Enum.map(leagues, &LeagueSettings.default_params/1)

    Repo.insert_all(LeagueSettings, league_settings_data,
      on_conflict: :nothing,
      conflict_target: :league_id
    )

    # Second round: update parent/child relationships.

    league_id_map = Map.new(leagues, &{&1.code, &1.id})
    league_data = Enum.map(first_leagues, &RM.Local.League.from_first_league(&1, league_id_map))

    leagues =
      Repo.insert_all(RM.Local.League, league_data,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:code, :region_id],
        returning: true
      )
      |> elem(1)

    # RM.FIRST.update_region_league_counts(leagues)
    leagues
  end

  @spec update_league(League.t(), map) :: {:ok, League.t()} | {:error, Changeset.t(League.t())}
  def update_league(league, params) do
    League.update_changeset(league, params)
    |> Repo.update()
  end

  #
  # League Settings
  #

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

  #
  # Teams
  #

  @spec list_registered_teams_by_event(Event.t()) :: [EventRegistration.t()]
  @spec list_registered_teams_by_event(Event.t(), keyword) :: [EventRegistration.t()]
  def list_registered_teams_by_event(event, opts \\ []) do
    Query.from_registration()
    |> where([registration: r], r.event_id == ^event.id)
    |> Query.rescinded(opts[:rescinded])
    |> Query.waitlisted(opts[:waitlisted])
    |> Query.preload_assoc(:registration, [:team])
    |> Query.preload_assoc(:registration, opts[:preload])
    |> Repo.all()
    |> Enum.sort_by(& &1.team, Team)
  end

  @spec list_teams_by_number([integer]) :: [Team.t()]
  @spec list_teams_by_number([integer], keyword) :: [Team.t()]
  def list_teams_by_number(numbers, opts \\ []) do
    Query.from_team()
    |> where([team: t], t.number in ^numbers)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.all()
  end

  @spec list_teams_by_region(Region.t()) :: [Team.t()]
  @spec list_teams_by_region(Region.t(), keyword) :: [Team.t()]
  def list_teams_by_region(region, opts \\ []) do
    Query.from_team()
    |> Query.active_team()
    |> where([team: t], t.region_id == ^region.id)
    |> Query.preload_assoc(:team, opts[:preload])
    |> Repo.all()
    |> Enum.sort(Team)
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

  #
  # Venues
  #

  @spec create_venue(League.t(), map) :: {:ok, Venue.t()} | {:error, Changeset.t(Venue.t())}
  def create_venue(league, params) do
    Venue.create_changeset(league, params)
    |> Repo.insert()
  end
end
