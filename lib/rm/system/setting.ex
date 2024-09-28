defmodule RM.System.Setting do
  @moduledoc """
  Key-value global configuration record

  See `RM.System.Config` for more information.

  Values in these records are serialized using `:erlang.term_to_binary/1` and
  `:erlang.binary_to_term/2` with the `:safe` option. This means that values cannot create new
  atoms not already present in the system (`nil` is okay) or include function references.

  Despite the use of the `:safe` option, a high level of trust must be placed in the binaries
  stored in this table, as they can still create functions.
  """
  use Ecto.Schema
  import Ecto.Query

  alias RM.Repo

  @typedoc "Global configuration record"
  @type t :: %__MODULE__{
          key: String.t(),
          description: String.t(),
          value: binary
        }

  @primary_key {:key, :string, autogenerate: false}
  schema "rm_settings" do
    field :description, :string
    field :value, :binary, default: :erlang.term_to_binary(nil)

    timestamps type: :utc_datetime_usec
  end

  @doc "Load all configuration records"
  @spec all :: [t]
  def all, do: Repo.all(__MODULE__)

  @doc "Get a configuration record by its key"
  @spec get(String.t()) :: t | nil
  def get(key), do: Repo.get(__MODULE__, key)

  @doc "Create a configuration record"
  @spec create(String.t(), String.t(), term) :: t | no_return
  def create(key, description, value) do
    serialized_value = :erlang.term_to_binary(value)

    %__MODULE__{key: key, description: description, value: serialized_value}
    |> Repo.insert!()
  end

  @doc "Update a configuration record"
  @spec update(String.t(), term) :: t | no_return
  def update(key, value) do
    serialized_value = :erlang.term_to_binary(value)

    query =
      from(s in __MODULE__, as: :setting)
      |> where([setting: s], s.key == ^key)
      |> update([setting: s], set: [value: ^serialized_value])
      |> select([setting: s], s)

    case Repo.update_all(query, []) do
      {1, [setting]} -> setting
      {0, _} -> raise Ecto.NoResultsError, queryable: query
      {count, _} -> raise Ecto.MultipleResultsError, count: count, queryable: query
    end
  end
end
