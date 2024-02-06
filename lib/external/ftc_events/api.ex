defmodule External.FTCEvents.API do
  @moduledoc """
  Interface for the [FTC Events API](https://ftc-events.firstinspires.org/services/API)

  This module defines the functions that can be used to interact with the API. The implementation
  of those functions can be found in `External.FTCEvents.API.Client` for production environments
  and a different module for development and testing. Which implementation is active depends on
  the configuration defined in `client/0`.
  """

  @typedoc "4-digit year when the season started"
  @type season :: integer

  #
  # Client Callbacks
  #

  @typedoc "Response from API calls"
  @type response(t) :: {:ok, t} | {:error, Exception.t()}
  @typedoc "Options for the `c:list_leagues/2` callback"
  @type list_leagues_options :: [{:region, String.t()} | {:league, String.t()}]
  @typedoc "Response data for the `c:list_leagues/2` callback"
  @type list_leagues_response :: %{count: integer, leagues: [map]}

  @doc false
  @callback list_leagues(season) :: response(list_leagues_response)
  @doc "Returns all FTC leagues in a particular season"
  @callback list_leagues(season, list_leagues_options) :: response(list_leagues_response)

  #
  # Configuration
  #

  @doc "Currently configured API client module"
  @spec client :: module
  def client do
    Application.get_env(:rm, External.FTCEvents.API, [])
    |> Keyword.get(:client, External.FTCEvents.API.Client)
  end
end
