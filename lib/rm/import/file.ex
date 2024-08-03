defmodule RM.Import.File do
  @moduledoc """
  File attachment and archive storage for uploaded CSV files
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  @doc false
  def filename(_version, {_file, scope}) do
    "#{scope.id}.csv"
  end

  @doc false
  def storage_dir(_version, _file_and_scope) do
    "import/#{Calendar.strftime(Date.utc_today(), "%Y/%m")}/"
  end

  @doc false
  def s3_object_headers(_version, _file_and_scope) do
    [content_type: "text/csv"]
  end
end
