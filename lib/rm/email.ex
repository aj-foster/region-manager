defmodule RM.Email do
  @moduledoc """
  Email-related functionality for Region Manager
  """
  import Ecto.Query

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
        ) :: {:ok, Address.t()} | {:error, Ecto.Changeset.t(Address.t())}
  def mark_email_undeliverable(email, :complaint) do
    list_contacts_by_email(email)
    |> Enum.each(fn contact ->
      Keila.Contacts.downgrade_contact_status(contact.id, :unreachable)
    end)

    now = DateTime.utc_now()

    %Address{
      email: email,
      complained_at: now
    }
    |> Repo.insert(
      on_conflict: [
        set: [complained_at: now, updated_at: now]
      ],
      conflict_target: [:email],
      returning: true
    )
  end

  def mark_email_undeliverable(email, :permanent_bounce) do
    list_contacts_by_email(email)
    |> Enum.each(fn contact ->
      Keila.Contacts.downgrade_contact_status(contact.id, :unreachable)
    end)

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
        set: [last_bounced_at: now, permanently_bounced_at: now, updated_at: now],
        inc: [bounce_count: 1]
      ],
      conflict_target: [:email],
      returning: true
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
        set: [last_bounced_at: now, updated_at: now],
        inc: [bounce_count: 1]
      ],
      conflict_target: [:email],
      returning: true
    )
    |> case do
      {:ok, address} ->
        if address.bounce_count >= 2 do
          list_contacts_by_email(email)
          |> Enum.each(fn contact ->
            Keila.Contacts.downgrade_contact_status(contact.id, :unreachable)
          end)
        end

        {:ok, address}

      error ->
        error
    end
  end

  def mark_email_undeliverable(email, :unsubscribe) do
    list_contacts_by_email(email)
    |> Enum.each(fn contact ->
      Keila.Contacts.downgrade_contact_status(contact.id, :unsubscribed)
    end)

    now = DateTime.utc_now()

    %Address{
      email: email,
      unsubscribed_at: now
    }
    |> Repo.insert(
      on_conflict: [
        set: [unsubscribed_at: now, updated_at: now]
      ],
      conflict_target: [:email]
    )
  end

  @doc """
  Remove manual unsubscribe mark from an email address
  """
  @spec resubscribe_address(Address.t()) ::
          {:ok, Address.t()} | {:error, Ecto.Changeset.t(Address.t())}
  def resubscribe_address(address) do
    list_contacts_by_email(address.email)
    |> Enum.each(fn contact ->
      Keila.Contacts.update_contact(contact.id, %{status: :active}, update_status: true)
    end)

    address
    |> Ecto.Changeset.change(unsubscribed_at: nil)
    |> Repo.update()
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

  #
  # Keila: Regions
  #

  @doc """
  Sync a single region to Keila, creating or updating the corresponding project as needed
  """
  @spec sync_project_for_region(RM.FIRST.Region.t()) ::
          {:ok, Keila.Projects.Project.t()}
          | {:error, Ecto.Changeset.t(Keila.Projects.Project.t())}
  def sync_project_for_region(region) do
    root_group = Keila.Auth.root_group()
    params = %{name: "#{region.name} Region (#{region.code})", group_id: root_group.id}

    if region.metadata.keila_project_id do
      Keila.Projects.update_project(region.metadata.keila_project_id, params)
    else
      params
      |> Keila.Projects.Project.creation_changeset()
      |> Keila.Repo.insert()
      |> case do
        {:ok, project} ->
          Ecto.Changeset.change(region, %{metadata: %{keila_project_id: project.id}})
          |> RM.Repo.update!()

          {:ok, project}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Sync a segment for a single region to Keila, creating or updating the corresponding segment as needed
  """
  @spec sync_segment_for_region(RM.FIRST.Region.t()) ::
          {:ok, Keila.Contacts.Segment.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Segment.t())}
  def sync_segment_for_region(region) do
    region_code = String.downcase(region.code)

    params = %{
      name: "#{region.name} Region (#{region.code})",
      project_id: region.metadata.keila_project_id,
      filter: %{"data.#{region_code}" => "true"}
    }

    if region.metadata.keila_segment_id do
      Keila.Contacts.update_segment(region.metadata.keila_segment_id, params)
    else
      case Keila.Contacts.create_segment(region.metadata.keila_project_id, params) do
        {:ok, segment} ->
          Ecto.Changeset.change(region, %{metadata: %{keila_segment_id: segment.id}})
          |> RM.Repo.update!()

          {:ok, segment}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Sync a coach segment for a single region to Keila, creating or updating the corresponding segment as needed
  """
  @spec sync_coach_segment_for_region(RM.FIRST.Region.t()) ::
          {:ok, Keila.Contacts.Segment.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Segment.t())}
  def sync_coach_segment_for_region(region) do
    region_code = String.downcase(region.code)

    params = %{
      name: "#{region.name} Region Coaches (#{region.code})",
      project_id: region.metadata.keila_project_id,
      filter: %{"$and" => [%{"data.#{region_code}" => "true"}, %{"data.coach" => "true"}]}
    }

    if region.metadata.keila_coach_segment_id do
      Keila.Contacts.update_segment(region.metadata.keila_coach_segment_id, params)
    else
      case Keila.Contacts.create_segment(region.metadata.keila_project_id, params) do
        {:ok, segment} ->
          Ecto.Changeset.change(region, %{metadata: %{keila_coach_segment_id: segment.id}})
          |> RM.Repo.update!()

          {:ok, segment}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Sync an extended coach segment for a single region to Keila, creating or updating the corresponding segment as needed
  """
  @spec sync_extended_coach_segment_for_region(RM.FIRST.Region.t()) ::
          {:ok, Keila.Contacts.Segment.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Segment.t())}
  def sync_extended_coach_segment_for_region(region) do
    region_code = String.downcase(region.code)

    params = %{
      name: "#{region.name} Region Coaches Extended (#{region.code})",
      project_id: region.metadata.keila_project_id,
      filter: %{
        "$and" => [
          %{"data.#{region_code}" => "true"},
          %{"$or" => [%{"data.coach" => "true"}, %{"data.coach_last_season" => "true"}]}
        ]
      }
    }

    if region.metadata.keila_extended_coach_segment_id do
      Keila.Contacts.update_segment(region.metadata.keila_extended_coach_segment_id, params)
    else
      case Keila.Contacts.create_segment(region.metadata.keila_project_id, params) do
        {:ok, segment} ->
          Ecto.Changeset.change(region, %{
            metadata: %{keila_extended_coach_segment_id: segment.id}
          })
          |> RM.Repo.update!()

          {:ok, segment}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  #
  # Keila: Leagues
  #

  @doc """
  Sync a single league to Keila, creating or updating the corresponding segment as needed
  """
  @spec sync_segment_for_league(RM.FIRST.Region.t(), RM.Local.League.t()) ::
          {:ok, Keila.Contacts.Segment.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Segment.t())}
  def sync_segment_for_league(region, league) do
    league_code = String.downcase(region.code <> league.code)

    params = %{
      name: "#{region.name} #{league.name} League (#{region.code}#{league.code})",
      project_id: region.metadata.keila_project_id,
      filter: %{"data.#{league_code}" => "true"}
    }

    if league.metadata.keila_segment_id do
      Keila.Contacts.update_segment(league.metadata.keila_segment_id, params)
    else
      case Keila.Contacts.create_segment(region.metadata.keila_project_id, params) do
        {:ok, segment} ->
          Ecto.Changeset.change(league, %{metadata: %{keila_segment_id: segment.id}})
          |> RM.Repo.update!()

          {:ok, segment}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Sync a coach segment for a single league to Keila, creating or updating the corresponding segment as needed
  """
  @spec sync_coach_segment_for_league(RM.FIRST.Region.t(), RM.Local.League.t()) ::
          {:ok, Keila.Contacts.Segment.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Segment.t())}
  def sync_coach_segment_for_league(region, league) do
    league_code = String.downcase(region.code <> league.code)

    params = %{
      name: "#{region.name} #{league.name} League Coaches (#{region.code}#{league.code})",
      project_id: region.metadata.keila_project_id,
      filter: %{"$and" => [%{"data.#{league_code}" => "true"}, %{"data.coach" => "true"}]}
    }

    if league.metadata.keila_coach_segment_id do
      Keila.Contacts.update_segment(league.metadata.keila_coach_segment_id, params)
    else
      case Keila.Contacts.create_segment(region.metadata.keila_project_id, params) do
        {:ok, segment} ->
          Ecto.Changeset.change(league, %{metadata: %{keila_coach_segment_id: segment.id}})
          |> RM.Repo.update!()

          {:ok, segment}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Sync an extended coach segment for a single league to Keila, creating or updating the corresponding segment as needed
  """
  @spec sync_extended_coach_segment_for_league(RM.FIRST.Region.t(), RM.Local.League.t()) ::
          {:ok, Keila.Contacts.Segment.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Segment.t())}
  def sync_extended_coach_segment_for_league(region, league) do
    league_code = String.downcase(region.code <> league.code)

    params = %{
      name:
        "#{region.name} #{league.name} League Coaches Extended (#{region.code}#{league.code})",
      project_id: region.metadata.keila_project_id,
      filter: %{
        "$and" => [
          %{"data.#{league_code}" => "true"},
          %{"$or" => [%{"data.coach" => "true"}, %{"data.coach_last_season" => "true"}]}
        ]
      }
    }

    if league.metadata.keila_extended_coach_segment_id do
      Keila.Contacts.update_segment(league.metadata.keila_extended_coach_segment_id, params)
    else
      case Keila.Contacts.create_segment(region.metadata.keila_project_id, params) do
        {:ok, segment} ->
          Ecto.Changeset.change(league, %{
            metadata: %{keila_extended_coach_segment_id: segment.id}
          })
          |> RM.Repo.update!()

          {:ok, segment}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  #
  # Keila: Users
  #

  @doc """
  Sync all coach contacts for a team to Keila, creating or updating the corresponding contacts as needed
  """
  @spec sync_coach_contacts_for_team(RM.Local.Team.t()) :: :ok
  def sync_coach_contacts_for_team(team) do
    if team.active do
      team = RM.Repo.preload(team, [:league, :region, :user_assignments])
      project_id = team.region.metadata.keila_project_id

      team.user_assignments
      |> Enum.filter(&(not is_nil(&1.email)))
      |> Enum.each(fn assignment ->
        league_code = if team.league, do: String.downcase(team.region.code <> team.league.code)
        sync_coach_contact(project_id, assignment.email, league_code, assignment.name)
      end)
    else
      :ok
    end
  end

  @spec sync_coach_contact(String.t(), String.t(), String.t() | nil, String.t()) ::
          {:ok, Keila.Contacts.Contact.t()}
          | {:error, Ecto.Changeset.t(Keila.Contacts.Contact.t())}
  defp sync_coach_contact(project_id, email, league_code, name) do
    {first_name, last_name} =
      case String.split(name, " ", parts: 2) do
        [first_name, last_name] -> {first_name, last_name}
        [first_name] -> {first_name, ""}
      end

    data =
      if league_code do
        %{"coach" => "true", league_code => "true"}
      else
        %{"coach" => "true"}
      end

    if contact = Keila.Contacts.get_project_contact_by_email(project_id, email) do
      data = Map.merge(contact.data || %{}, data)
      Keila.Contacts.update_contact(contact.id, %{data: data})
    else
      status =
        case get_address(email) do
          %Address{unsubscribed_at: %DateTime{}} -> :unsubscribed
          %Address{sendable: false} -> :bounced
          _else -> :active
        end

      Keila.Contacts.create_contact(
        project_id,
        %{
          email: email,
          first_name: first_name,
          data: data,
          last_name: last_name,
          status: status
        },
        set_status: true
      )
    end
  end

  @doc """
  List all contacts in Keila with the given email address, across all projects
  """
  @spec list_contacts_by_email(String.t()) :: [Keila.Contacts.Contact.t()]
  def list_contacts_by_email(email) do
    from(Keila.Contacts.Contact, as: :contact)
    |> where([contact: c], c.email == ^email)
    |> join(:inner, [contact: c], p in assoc(c, :project), as: :project)
    |> preload([project: p], project: p)
    |> Keila.Repo.all()
  end
end
