defmodule RM.System do
  @moduledoc """
  Entrypoint for system configuration and feedback
  """

  alias Ecto.Changeset
  alias RM.Repo
  alias RM.System.Feedback

  #
  # Config
  #

  @doc "Get the currently configured season"
  @spec current_season :: integer
  def current_season do
    RM.System.Config.get("current_season")
  end

  #
  # Feedback
  #

  @doc "Create a new feedback record"
  @spec create_feedback(map) :: {:ok, Feedback.t()} | {:error, Changeset.t(Feedback.t())}
  def create_feedback(params) do
    Feedback.create_changeset(params)
    |> Repo.insert()
  end

  @doc "Mark a feedback record as completed"
  @spec complete_feedback(Feedback.t()) ::
          {:ok, Feedback.t()} | {:error, Changeset.t(Feedback.t())}
  def complete_feedback(feedback) do
    Feedback.complete_changeset(feedback)
    |> Repo.update()
  end
end
