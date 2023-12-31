defmodule RM.FIRST.Query do
  @moduledoc """
  Query helpers for schemas in the FIRST namespace
  """
  import Ecto.Query

  alias RM.FIRST.Region

  @typedoc "Intermediate query"
  @type query :: Ecto.Query.t()

  #
  # Base
  #

  @doc "Start a query from the regions table"
  @spec from_region :: query
  def from_region do
    from(Region, as: :region)
  end

  #
  # Filters
  #

  @doc "Find the region with a given name"
  @spec region_name(query, String.t()) :: query
  def region_name(query, name) do
    where(query, [region: r], fragment("LOWER(?) = ?", r.name, ^String.downcase(name)))
  end

  #
  # Joins
  #

  @doc "Load the `teams` association on a region"
  @spec join_teams_from_region(query) :: query
  def join_teams_from_region(query) do
    with_named_binding(query, :teams, fn query, binding ->
      join(query, :left, [region: r], t in assoc(r, :teams), as: ^binding)
    end)
  end

  #
  # Preloads
  #

  @doc """
  Preload data in a single query

  Data preloaded with this function will be joined and loaded in a single query, which can cause
  performance issues. The associations supported are:

    * `users`: `teams` on a region

  """
  @spec preload_assoc(query, [atom] | nil) :: query
  def preload_assoc(query, associations)
  def preload_assoc(query, nil), do: query
  def preload_assoc(query, []), do: query

  def preload_assoc(query, [:teams | rest]) do
    query
    |> join_teams_from_region()
    |> preload([teams: t], teams: t)
    |> preload_assoc(rest)
  end
end
