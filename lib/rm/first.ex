defmodule RM.FIRST do
  @moduledoc """
  Entrypoint for data managed by FIRST
  """
  alias RM.FIRST.Region
  alias RM.FIRST.Query
  alias RM.Repo

  @spec get_region_by_name(String.t(), keyword) :: Region.t() | nil
  def get_region_by_name(name, opts \\ []) do
    Query.from_region()
    |> Query.region_name(name)
    |> Query.preload_assoc(opts[:preload])
    |> Repo.one()
  end
end
