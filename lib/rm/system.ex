defmodule RM.System do
  @moduledoc """
  Entrypoint for system configuration and feedback
  """

  @doc "Get the currently configured season"
  @spec current_season :: integer
  def current_season do
    RM.System.Config.get("current_season")
  end
end
