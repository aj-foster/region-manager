defmodule RM.Util.Time do
  @moduledoc """
  Timezone utilities

  Provides `zones/0`, which can be used to populate a list of timezones in a user interface. The
  information in this module is not suitable for general use, and must be updated as new timezone
  databases are released. Specifically,

    * Timezones are grouped, and some timezones eliminated completely, based on what those zones
      are expected to do **in the future**. They are distinct timezones because of what happened
      in the past, and it is **not valid** to use them interchangeably when considering times
      that occurred in the past.

    * Timezones are labeled in ways that may be inappropriate. In many cases, groups are labeled
      using the largest city included in the group (ex. New York). In other cases, the first city
      in the group is used.

  The labels are deliberately optimized for full text search, as might occur when using a
  `<datalist>` element. They include commonly-used
  """

  #
  # Timezone Database Modifications
  #

  # Groups of timezones identified by `find_equivalent_future_timezones/0` that all have the same
  # future periods (meaning that times in the past may not be exactly the same, but times in the
  # future are currently expected to remain the same). For each group, a canonical name is chosen.
  # In many cases this is just the first name of the group; in some cases, it's possible to choose
  # a more commonly-used name.
  #
  # Last updated for 2024a.
  #
  @tz_consolidation %{
    "Africa/Casablanca" => ["Africa/Casablanca", "Africa/El_Aaiun"],
    "WET" => ["Atlantic/Canary", "Atlantic/Faroe", "Atlantic/Madeira", "Europe/Lisbon", "WET"],
    "Australia/Adelaide" => ["Australia/Adelaide", "Australia/Broken_Hill"],
    "Asia/Gaza" => ["Asia/Gaza", "Asia/Hebron"],
    "America/Argentina/San_Juan" => [
      "America/Argentina/Catamarca",
      "America/Argentina/Jujuy",
      "America/Argentina/La_Rioja",
      "America/Argentina/Mendoza",
      "America/Argentina/Rio_Gallegos",
      "America/Argentina/Salta",
      "America/Argentina/San_Juan",
      "America/Argentina/Ushuaia"
    ],
    "America/Anchorage" => [
      "America/Anchorage",
      "America/Juneau",
      "America/Metlakatla",
      "America/Nome",
      "America/Sitka",
      "America/Yakutat"
    ],
    "America/Chicago" => [
      "America/Chicago",
      "America/Indiana/Knox",
      "America/Indiana/Tell_City",
      "America/Matamoros",
      "America/Menominee",
      "America/North_Dakota/Beulah",
      "America/North_Dakota/Center",
      "America/North_Dakota/New_Salem",
      "America/Ojinaga",
      "America/Rankin_Inlet",
      "America/Resolute",
      "America/Winnipeg",
      "CST6CDT"
    ],
    "America/Denver" => [
      "America/Boise",
      "America/Cambridge_Bay",
      "America/Ciudad_Juarez",
      "America/Denver",
      "America/Edmonton",
      "America/Inuvik",
      "MST7MDT"
    ],
    "America/Dawson" => ["America/Dawson", "America/Whitehorse"],
    "Europe/Moscow" => ["Europe/Kirov", "Europe/Moscow", "Europe/Simferopol"],
    "EET" => [
      "Asia/Famagusta",
      "Asia/Nicosia",
      "EET",
      "Europe/Athens",
      "Europe/Bucharest",
      "Europe/Helsinki",
      "Europe/Kyiv",
      "Europe/Riga",
      "Europe/Sofia",
      "Europe/Tallinn",
      "Europe/Vilnius"
    ],
    "America/Campo_Grande" => ["America/Campo_Grande", "America/Cuiaba"],
    "Asia/Anadyr" => ["Asia/Anadyr", "Asia/Kamchatka"],
    "America/Eirunepe" => ["America/Eirunepe", "America/Rio_Branco"],
    "Europe/Astrakhan" => ["Europe/Astrakhan", "Europe/Ulyanovsk"],
    "CET" => [
      "Africa/Ceuta",
      "CET",
      "Europe/Andorra",
      "Europe/Belgrade",
      "Europe/Berlin",
      "Europe/Brussels",
      "Europe/Budapest",
      "Europe/Gibraltar",
      "Europe/Madrid",
      "Europe/Malta",
      "Europe/Paris",
      "Europe/Prague",
      "Europe/Rome",
      "Europe/Tirane",
      "Europe/Vienna",
      "Europe/Warsaw",
      "Europe/Zurich"
    ],
    "Australia/Melbourne" => [
      "Antarctica/Macquarie",
      "Australia/Hobart",
      "Australia/Melbourne",
      "Australia/Sydney"
    ],
    "America/Nuuk" => ["America/Nuuk", "America/Scoresbysund"],
    "Asia/Almaty" => ["Asia/Almaty", "Asia/Qostanay"],
    "Asia/Choibalsan" => ["Asia/Choibalsan", "Asia/Ulaanbaatar"],
    "Asia/Khandyga" => ["Asia/Khandyga", "Asia/Yakutsk"],
    "America/Los_Angeles" => [
      "America/Los_Angeles",
      "America/Tijuana",
      "America/Vancouver",
      "PST8PDT"
    ],
    "America/Argentina/Buenos_Aires" => [
      "America/Argentina/Buenos_Aires",
      "America/Argentina/Cordoba",
      "America/Argentina/Tucuman"
    ],
    "America/Mexico_City" => [
      "America/Bahia_Banderas",
      "America/Merida",
      "America/Mexico_City",
      "America/Monterrey"
    ],
    "Asia/Aqtau" => ["Asia/Aqtau", "Asia/Atyrau", "Asia/Oral"],
    "America/Glace_Bay" => [
      "America/Glace_Bay",
      "America/Goose_Bay",
      "America/Halifax",
      "America/Moncton",
      "America/Thule",
      "Atlantic/Bermuda"
    ],
    "America/Punta_Arenas" => ["America/Punta_Arenas", "Antarctica/Palmer"],
    "Asia/Samarkand" => ["Asia/Samarkand", "Asia/Tashkent"],
    "Asia/Ust-Nera" => ["Asia/Ust-Nera", "Asia/Vladivostok"],
    "America/Fortaleza" => ["America/Fortaleza", "America/Maceio", "America/Recife"],
    "America/New_York" => [
      "America/Detroit",
      "America/Grand_Turk",
      "America/Indiana/Indianapolis",
      "America/Indiana/Marengo",
      "America/Indiana/Petersburg",
      "America/Indiana/Vevay",
      "America/Indiana/Vincennes",
      "America/Indiana/Winamac",
      "America/Iqaluit",
      "America/Kentucky/Louisville",
      "America/Kentucky/Monticello",
      "America/New_York",
      "America/Port-au-Prince",
      "America/Toronto",
      "EST5EDT"
    ]
  }

  @tz_consolidation_aliases MapSet.difference(
                              Map.values(@tz_consolidation) |> List.flatten() |> MapSet.new(),
                              Map.keys(@tz_consolidation) |> MapSet.new()
                            )

  # Nice, unofficial names for timezones. Assigned to group names.
  @tz_affordances %{
    "America/New_York" => "Eastern US",
    "America/Chicago" => "Central US",
    "America/Denver" => "Mountain US",
    "America/Los_Angeles" => "Pacific US",
    "WET" => "WET",
    "CET" => "CET",
    "EET" => "EET"
  }

  # Unnecessarily verbose alternative timezone names. Also exclude unofficial names from the
  # exhaustive list of names, because the unofficial names will already be shown earlier.
  @tz_exclusions MapSet.new(
                   [
                     "America/Indiana/Indianapolis",
                     "America/Indiana/Marengo",
                     "America/Indiana/Knox",
                     "America/Indiana/Petersburg",
                     "America/Indiana/Tell_City",
                     "America/Indiana/Vevay",
                     "America/Indiana/Vincennes",
                     "America/Indiana/Winamac",
                     "America/Kentucky/Louisville",
                     "America/Kentucky/Monticello",
                     "America/North_Dakota/Beulah",
                     "America/North_Dakota/Center",
                     "America/North_Dakota/New_Salem",
                     "EST5EDT",
                     "CST6CDT",
                     "MST7MDT",
                     "PST8PDT"
                   ] ++ Map.values(@tz_affordances)
                 )

  # Finds groups of timezones that have equivalent rules for the future. This information can be
  # used to remove timezones from a list **as long as the selection is for future dates only**.
  # These timezones exist for a reason, but usually it's because of variations in the past.
  @doc false
  @spec find_equivalent_future_timezones :: [[String.t()]]
  def find_equivalent_future_timezones do
    now = DateTime.utc_now() |> DateTime.to_gregorian_seconds() |> elem(0)

    Tzdata.canonical_zone_list()
    |> Enum.map(fn timezone ->
      periods =
        Tzdata.periods(timezone)
        |> elem(1)
        |> Enum.reject(&(&1.until.utc < now))

      %{name: timezone, periods: periods}
    end)
    |> Enum.group_by(& &1.periods, & &1.name)
    |> Map.values()
    |> Enum.reject(&(length(&1) < 2))
  end

  @doc """
  Returns a "nice" name of the timezone if one is available
  """
  @spec zone_nice_name(String.t()) :: String.t()
  def zone_nice_name(timezone) do
    Map.get(@tz_affordances, timezone, timezone)
  end

  #
  # Timezone Options
  #

  @doc """
  Create a list of timezone options suitable for an HTML `<datalist>`

  Timezones are ordered roughly from East to West based on their current offsets. Labels are
  optimized for full text search by city or common zone names, as would occur in a datalist.
  """
  @spec zones :: [{String.t(), String.t()}]
  def zones do
    now = DateTime.utc_now() |> DateTime.to_gregorian_seconds() |> elem(0)

    Tzdata.canonical_zone_list()
    |> Enum.reject(&MapSet.member?(@tz_consolidation_aliases, &1))
    |> Enum.map(&period_for(&1, now))
    |> Enum.sort(&timezone_sorter/2)
    |> Enum.map(fn tz ->
      names =
        if aliases = Map.get(@tz_consolidation, tz.name) do
          aliases
          |> Enum.reject(&MapSet.member?(@tz_exclusions, &1))
          |> list_names()
        else
          list_names([tz.name])
        end

      offset = tz.utc_off + tz.std_off
      hour_offset = div(offset, 3600)
      minute_offset = div(rem(offset, 3600), 60)

      offset_str =
        Enum.join([
          if(offset < 0, do: "–", else: "+"),
          String.pad_leading("#{abs(hour_offset)}", 2, "0"),
          ":",
          String.pad_leading("#{abs(minute_offset)}", 2, "0")
        ])

      affordance = Map.get(@tz_affordances, tz.name)
      generic_abbr? = tz.zone_abbr == "LMT" or String.match?(tz.zone_abbr, ~r/^-\d+$/)

      label =
        cond do
          affordance && generic_abbr? ->
            "#{affordance} • #{names} • GMT#{offset_str}"

          affordance && !generic_abbr? ->
            "#{affordance} (#{tz.zone_abbr}) • #{names} • GMT#{offset_str}"

          is_nil(affordance) && generic_abbr? ->
            "#{names} • GMT#{offset_str}"

          is_nil(affordance) && !generic_abbr? ->
            "#{tz.zone_abbr} • #{names} • GMT#{offset_str}"
        end

      {tz.name, label}
    end)
  end

  @doc """
  Create a filtered list of timezone options suitable for an HTML `<select>`

  Timezones are ordered roughly from East to West based on their current offsets. Labels are
  optimized for clarity, using only the city names allowed by the country restriction.
  """
  @spec zones_for_country(String.t()) :: [{String.t(), String.t()}]
  def zones_for_country(country_name) do
    now = DateTime.utc_now() |> DateTime.to_gregorian_seconds() |> elem(0)
    allowed_timezones = RM.Util.Location.timezones(country_name)

    allowed_timezones
    |> Enum.map(&period_for(&1, now))
    |> Enum.sort(&timezone_sorter/2)
    |> Enum.map(fn tz ->
      names =
        if aliases = Map.get(@tz_consolidation, tz.name) do
          aliases
          |> Enum.filter(&(&1 in allowed_timezones))
          |> Enum.reject(&MapSet.member?(@tz_exclusions, &1))
          |> list_names()
        else
          list_names([tz.name])
        end

      offset = tz.utc_off + tz.std_off
      hour_offset = div(offset, 3600)
      minute_offset = div(rem(offset, 3600), 60)

      offset_str =
        Enum.join([
          if(offset < 0, do: "–", else: "+"),
          String.pad_leading("#{abs(hour_offset)}", 2, "0"),
          ":",
          String.pad_leading("#{abs(minute_offset)}", 2, "0")
        ])

      affordance = Map.get(@tz_affordances, tz.name)
      generic_abbr? = tz.zone_abbr == "LMT" or String.match?(tz.zone_abbr, ~r/^-\d+$/)

      label =
        cond do
          affordance && generic_abbr? ->
            "#{affordance} • #{names} • GMT#{offset_str}"

          affordance && !generic_abbr? ->
            "#{affordance} (#{tz.zone_abbr}) • #{names} • GMT#{offset_str}"

          is_nil(affordance) && generic_abbr? ->
            "#{names} • GMT#{offset_str}"

          is_nil(affordance) && !generic_abbr? ->
            "#{tz.zone_abbr} • #{names} • GMT#{offset_str}"
        end

      {label, tz.name}
    end)
  end

  @spec period_for(String.t(), pos_integer) :: map
  defp period_for(timezone, unix_now) do
    case Tzdata.periods_for_time(timezone, unix_now, :utc) do
      [] ->
        raise RuntimeError,
          message: "Current time #{unix_now} is invalid for timezone #{timezone}"

      [period] ->
        Map.put(period, :name, timezone)

      [_first, second] ->
        Map.put(second, :name, timezone)
    end
  end

  @spec list_names([String.t()]) :: String.t()
  defp list_names(names) do
    names
    |> Enum.map_join(", ", fn name ->
      name
      |> String.split("/")
      |> List.last()
      |> String.replace("_", " ")
    end)
  end

  # Callback for Enum.sort/2
  @spec timezone_sorter(map, map) :: boolean
  defp timezone_sorter(a, b) do
    a_offset = a.utc_off + a.std_off
    b_offset = b.utc_off + b.std_off

    cond do
      a_offset > b_offset -> true
      a_offset < b_offset -> false
      a_offset == b_offset -> a.name <= b.name
    end
  end
end
