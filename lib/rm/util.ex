defmodule RM.Util do
  @moduledoc """
  Small utility functions for working with data
  """

  @doc """
  Extract a list of IDs from the given `data`, unless they are already IDs

  Optionally pass `field` to choose which field to retrieve.
  """
  @spec extract_ids(struct | Ecto.UUID.t() | nil | [struct | Ecto.UUID.t()]) :: [Ecto.UUID.t()]
  @spec extract_ids(struct | Ecto.UUID.t() | nil | [struct | Ecto.UUID.t()], atom) ::
          [Ecto.UUID.t()]
  def extract_ids(data, field \\ :id)
  def extract_ids(nil, _field), do: []
  def extract_ids(data, field) when is_list(data), do: Enum.map(data, &extract_id(&1, field))
  def extract_ids(data, field), do: [extract_id(data, field)]

  @doc """
  Extract an ID from the given `data`, unless it's already an ID

  Optionally pass `field` to choose which field to retrieve.
  """
  @spec extract_id(struct | Ecto.UUID.t() | nil) :: Ecto.UUID.t()
  @spec extract_id(struct | Ecto.UUID.t() | nil, atom) :: Ecto.UUID.t()
  def extract_id(data, field \\ :id)
  def extract_id(nil, _field), do: nil
  def extract_id(data, field) when is_struct(data), do: Map.fetch!(data, field)
  def extract_id(data, _field) when is_binary(data), do: data
end
