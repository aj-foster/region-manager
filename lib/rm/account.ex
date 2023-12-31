defmodule RM.Account do
  @moduledoc """
  Entrypoint for account-related data management

  ## Query Options

  The following query options are common to many data-related functions:

    * `preload`: List of associations (as atoms) to preload.

  """
  alias RM.Account.Query
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
end
