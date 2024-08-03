defmodule RM.Util.Location do
  @moduledoc """
  Location utilities

  This module provides information about the countries and states/provinces supported by Region
  Manager. While there are libraries available for this information, this module follows the
  exact data used by FIRST. For example, the US state "Armed Forces - Americas" contains a dash,
  and the Canadian province "Québec" includes the acute accent.

  Countries should be added to this module whenever their regions adopt Region Manager.
  """

  # Countries, states, and provinces as they appear in event Batch Create spreadsheets
  @database %{
    "Canada" => %{
      state_province_required: true,
      state_provinces: [
        "Alberta",
        "British Columbia",
        "Manitoba",
        "New Brunswick",
        "Newfoundland and Labrador",
        "Northwest Territories",
        "Nova Scotia",
        "Nunavut",
        "Ontario",
        "Prince Edward Island",
        "Québec",
        "Saskatchewan",
        "Yukon Territory"
      ],
      timezones: [
        "America/St_Johns",
        "America/Halifax",
        "America/Glace_Bay",
        "America/Moncton",
        "America/Goose_Bay",
        "America/Toronto",
        "America/Iqaluit",
        "America/Winnipeg",
        "America/Resolute",
        "America/Rankin_Inlet",
        "America/Regina",
        "America/Swift_Current",
        "America/Edmonton",
        "America/Cambridge_Bay",
        "America/Inuvik",
        "America/Dawson_Creek",
        "America/Fort_Nelson",
        "America/Whitehorse",
        "America/Dawson",
        "America/Vancouver",
        "America/Panama",
        "America/Puerto_Rico",
        "America/Phoenix"
      ]
    },
    "United States" => %{
      state_province_required: true,
      state_provinces: [
        "Alabama",
        "Alaska",
        "American Samoa",
        "Arizona",
        "Arkansas",
        "Armed Forces - Americas",
        "Armed Forces - Europe",
        "Armed Forces - Pacific",
        "California",
        "Colorado",
        "Connecticut",
        "Delaware",
        "District of Columbia",
        "Florida",
        "Georgia",
        "Guam",
        "Hawaii",
        "Idaho",
        "Illinois",
        "Indiana",
        "Iowa",
        "Kansas",
        "Kentucky",
        "Louisiana",
        "Maine",
        "Maryland",
        "Massachusetts",
        "Michigan",
        "Minnesota",
        "Mississippi",
        "Missouri",
        "Montana",
        "Nebraska",
        "Nevada",
        "New Hampshire",
        "New Jersey",
        "New Mexico",
        "New York",
        "North Carolina",
        "North Dakota",
        "Northern Mariana Islands",
        "Ohio",
        "Oklahoma",
        "Oregon",
        "Pennsylvania",
        "Puerto Rico",
        "Rhode Island",
        "South Carolina",
        "South Dakota",
        "Tennessee",
        "Texas",
        "United States Minor Outlying Islands",
        "Utah",
        "Vermont",
        "Virgin Islands",
        "Virginia",
        "Washington",
        "West Virginia",
        "Wisconsin",
        "Wyoming"
      ],
      timezones: [
        "America/Puerto_Rico",
        "America/New_York",
        "America/Chicago",
        "America/Denver",
        "America/Phoenix",
        "America/Los_Angeles",
        "America/Anchorage",
        "America/Adak",
        "Pacific/Honolulu"
      ]
    }
  }

  @countries Map.keys(@database) |> Enum.sort()

  @doc """
  Create a list of countries supported by Region Manager
  """
  @spec countries :: [String.t()]
  def countries, do: @countries

  @doc """
  Create a list of states/provinces for the given country
  """
  @spec state_provinces(String.t()) :: [String.t()]
  def state_provinces(country_name) do
    case Map.fetch(@database, country_name) do
      {:ok, %{state_provinces: state_provinces}} -> state_provinces
      :error -> []
    end
  end

  @doc """
  Return whether a state/province is required when writing an address in the given country
  """
  @spec state_province_required?(String.t()) :: boolean
  def state_province_required?(country_name) do
    case Map.fetch(@database, country_name) do
      {:ok, %{state_province_required: state_province_required}} -> state_province_required
      :error -> false
    end
  end

  @doc """
  Create a list of allowed timezones for the given country
  """
  @spec timezones(String.t()) :: [String.t()]
  def timezones(country_name) do
    case Map.fetch(@database, country_name) do
      {:ok, %{timezones: timezones}} -> timezones
      :error -> []
    end
  end
end
