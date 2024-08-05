defmodule RM.Account do
  @moduledoc """
  Entrypoint for account-related data management

  ## Query Options

  The following query options are common to many data-related functions:

    * `preload`: List of associations (as atoms) to preload.

  """
  alias Ecto.Changeset
  alias RM.Account.League
  alias RM.Account.Profile
  alias RM.Account.Query
  alias RM.Account.Team
  alias RM.Account.User
  alias RM.Repo

  @doc """
  Get a single `User` by ID

  Raises if the user does not exist. Accepts common **Query Options**.
  """
  @spec get_user_by_id!(Ecto.UUID.t(), keyword) :: User.t()
  def get_user_by_id!(id, opts \\ []) do
    Query.from_user()
    |> Query.preload_assoc(opts[:preload])
    |> Repo.get!(id)
  end

  @doc """
  Load and return regions assigned to the given user
  """
  @spec get_regions_for_user(User.t()) :: [RM.FIRST.Region.t()]
  def get_regions_for_user(user) do
    user = Repo.preload(user, :regions)
    user.regions
  end

  @doc """
  Create a user, email, login, and profile
  """
  @spec create_user(map, keyword) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t(User.create_data())}
  def create_user(params, opts \\ []) do
    opts =
      Keyword.put(opts, :run, fn %{user: user} ->
        Profile.create_changeset(params, user)
        |> Repo.insert()
      end)

    Identity.create_email_and_login(params, opts)
  end

  @doc """
  Confirm and email address by its confirmation token and relink coaches with that email
  """
  @spec confirm_email(String.t()) ::
          {:ok, Identity.Schema.Email.t()} | {:error, :invalid | :not_found}
  def confirm_email(token) do
    with {:ok, email} <- Identity.confirm_email(token) do
      League.user_update_by_email_query(email.email)
      |> Repo.update_all([])

      Team.user_update_by_email_query(email.email)
      |> Repo.update_all([])

      {:ok, email}
    end
  end

  #
  # League Users
  #

  @doc """
  Add user as a league admin
  """
  @spec add_league_user(RM.Local.League.t(), map) ::
          {:ok, League.t()} | {:error, Changeset.t(League.t())}
  def add_league_user(league, params) do
    changeset = League.create_changeset(league, params)

    with {:ok, assignment} <- Repo.insert(changeset) do
      League.user_update_by_email_query(assignment.email)
      |> Repo.update_all([])

      {:ok, assignment}
    end
  end
end
