defmodule RM.Util.Location do
  @moduledoc """
  Location utilities

  This module provides information about the countries and states/provinces supported by Region
  Manager. While there are libraries available for this information, this module follows the
  exact data used by FIRST. For example, the US state "Armed Forces - Americas" contains a dash,
  and the Canadian province "Québec" includes the acute accent.

  Countries should be added to this module whenever their regions adopt Region Manager.
  """

  # Names as they appear in event Batch Create spreadsheets, paired with postal abbreviations
  @database %{
    "Canada" => %{
      state_province_required: true,
      state_provinces: [
        {"Alberta", "AB"},
        {"British Columbia", "BC"},
        {"Manitoba", "MB"},
        {"New Brunswick", "NB"},
        {"Newfoundland and Labrador", "NL"},
        {"Northwest Territories", "NT"},
        {"Nova Scotia", "NS"},
        {"Nunavut", "NU"},
        {"Ontario", "ON"},
        {"Prince Edward Island", "PE"},
        {"Québec", "QC"},
        {"Saskatchewan", "SK"},
        {"Yukon Territory", "YT"}
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
      published_abbreviation: "USA",
      state_province_required: true,
      state_provinces: [
        {"Alabama", "AL"},
        {"Alaska", "AK"},
        {"American Samoa", "AS"},
        {"Arizona", "AZ"},
        {"Arkansas", "AR"},
        {"Armed Forces - Americas", "AA"},
        {"Armed Forces - Europe", "AE"},
        {"Armed Forces - Pacific", "AP"},
        {"California", "CA"},
        {"Colorado", "CO"},
        {"Connecticut", "CT"},
        {"Delaware", "DE"},
        {"District of Columbia", "DC"},
        {"Florida", "FL"},
        {"Georgia", "GA"},
        {"Guam", "GU"},
        {"Hawaii", "HI"},
        {"Idaho", "ID"},
        {"Illinois", "IL"},
        {"Indiana", "IN"},
        {"Iowa", "IA"},
        {"Kansas", "KS"},
        {"Kentucky", "KY"},
        {"Louisiana", "LA"},
        {"Maine", "ME"},
        {"Maryland", "MD"},
        {"Massachusetts", "MA"},
        {"Michigan", "MI"},
        {"Minnesota", "MN"},
        {"Mississippi", "MS"},
        {"Missouri", "MO"},
        {"Montana", "MT"},
        {"Nebraska", "NE"},
        {"Nevada", "NV"},
        {"New Hampshire", "NH"},
        {"New Jersey", "NJ"},
        {"New Mexico", "NM"},
        {"New York", "NY"},
        {"North Carolina", "NC"},
        {"North Dakota", "ND"},
        {"Northern Mariana Islands", "MP"},
        {"Ohio", "OH"},
        {"Oklahoma", "OK"},
        {"Oregon", "OR"},
        {"Pennsylvania", "PA"},
        {"Puerto Rico", "PR"},
        {"Rhode Island", "RI"},
        {"South Carolina", "SC"},
        {"South Dakota", "SD"},
        {"Tennessee", "TN"},
        {"Texas", "TX"},
        {"United States Minor Outlying Islands", "UM"},
        {"Utah", "UT"},
        {"Vermont", "VT"},
        {"Virgin Islands", "VI"},
        {"Virginia", "VA"},
        {"Washington", "WA"},
        {"West Virginia", "WV"},
        {"Wisconsin", "WI"},
        {"Wyoming", "WY"}
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
  Return the country abbreviation used by published events, if one is configured.
  """
  @spec published_abbreviation(String.t() | nil) :: String.t() | nil
  def published_abbreviation(country_name) do
    case Map.fetch(@database, country_name) do
      {:ok, %{published_abbreviation: abbreviation}} -> abbreviation
      _ -> nil
    end
  end

  @doc """
  Create a list of {full name, postal abbreviation} pairs for the given country.
  """
  @spec state_provinces(String.t() | nil) :: [{String.t(), String.t()}]
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
