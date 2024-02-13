defmodule External.FTCEvents do
  @moduledoc """
  Interface for the [FTC Events API](https://ftc-events.firstinspires.org/services/API) and
  related data
  """
  alias RM.FIRST.Region
  alias External.FTCEvents.API

  @season 2023

  @spec list_leagues(Region.t()) :: API.response(API.list_leagues_response())
  def list_leagues(region) do
    %Region{code: region_code} = region
    API.client().list_leagues(@season, region: region_code)
  end
end
