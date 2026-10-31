defmodule RM.Util.Postcode do
  @moduledoc """
  Provides coordinates for US postal codes from the postal code dataset.
  """

  @postal_codes_path Path.expand("../../../data/US_POSTAL_CODES.txt", __DIR__)
  @external_resource @postal_codes_path

  @postal_code_coordinates @postal_codes_path
                           |> File.stream!()
                           |> Enum.reduce(%{}, fn line, coordinates ->
                             case String.split(line, "\t") do
                               [
                                 "US",
                                 postal_code,
                                 _place_name,
                                 _admin_name1,
                                 _admin_code1,
                                 _admin_name2,
                                 _admin_code2,
                                 _admin_name3,
                                 _admin_code3,
                                 latitude,
                                 longitude | _rest
                               ] ->
                                 case {Float.parse(latitude), Float.parse(longitude)} do
                                   {{latitude, ""}, {longitude, ""}} ->
                                     Map.put_new(coordinates, postal_code, {latitude, longitude})

                                   _ ->
                                     raise ArgumentError,
                                           "Invalid coordinates for US postal code #{postal_code}"
                                 end

                               ["US" | _] ->
                                 raise ArgumentError, "Invalid row in US postal code dataset"

                               _ ->
                                 coordinates
                             end
                           end)

  @type coordinates :: {float(), float()}

  @doc """
  Returns the latitude and longitude for a US postal code, or `nil` if it is not in the dataset.

  When a postal code appears more than once, the first dataset entry is used.
  """
  @spec coordinates(String.t()) :: coordinates() | nil
  def coordinates(postal_code), do: Map.get(@postal_code_coordinates, postal_code)
end
