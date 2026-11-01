defmodule RM.Import.FileTest do
  use ExUnit.Case, async: true

  alias RM.Import.File

  test "uses the upload ID as the CSV filename" do
    assert File.filename(:original, {nil, %{id: "upload-id"}}) == "upload-id.csv"
  end

  test "sets the file ACL to private" do
    assert File.acl(:original, {nil, %{id: "upload-id"}}) == :private
  end

  test "stores files under the current year and month" do
    assert File.storage_dir(:original, nil) ==
             "import/#{Calendar.strftime(Date.utc_today(), "%Y/%m")}/"
  end

  test "sets the CSV content type" do
    assert File.s3_object_headers(:original, nil) == [content_type: "text/csv"]
  end
end
