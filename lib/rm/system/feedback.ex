defmodule RM.System.Feedback do
  use Ecto.Schema

  alias Ecto.Changeset

  @typedoc "Types of feedback given"
  @type category :: :issue | :request | :other
  @categories [:issue, :request, :other]

  @typedoc "Feedback record"
  @type t :: %__MODULE__{
          category: category,
          completed_at: DateTime.t() | nil,
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          message: String.t(),
          user_agent: String.t(),
          user_id: Ecto.UUID.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "rm_feedback" do
    field :category, Ecto.Enum, values: @categories
    field :message, :string
    field :user_agent, :string
    field :user_id, Ecto.UUID

    timestamps type: :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
  end

  #
  # Changesets
  #

  @doc "Changeset for creating a new feedback entry"
  @spec create_changeset(map) :: Changeset.t(t)
  def create_changeset(params) do
    %__MODULE__{}
    |> Changeset.cast(params, [:category, :message, :user_agent, :user_id])
    |> Changeset.validate_required([:category, :message, :user_agent, :user_id])
  end

  @doc "Changeset for marking a piece of feedback as completed"
  @spec complete_changeset(t) :: Changeset.t(t)
  def complete_changeset(feedback) do
    Changeset.change(feedback, completed_at: DateTime.utc_now())
  end
end
