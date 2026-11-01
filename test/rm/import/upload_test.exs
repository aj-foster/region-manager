defmodule RM.Import.UploadTest do
  use RM.DataCase, async: true

  alias RM.Import.Upload

  test "creates a valid upload changeset with its file and importing user" do
    user = %RM.Account.User{id: Ecto.UUID.generate()}
    changeset = Upload.new(user, "test/fixture/import.csv")
    upload = apply_changes(changeset)

    assert changeset.valid?
    assert Ecto.UUID.cast(upload.id) == {:ok, upload.id}
    assert upload.imported_by == user.id
    assert %DateTime{} = upload.imported_at
    assert upload.file.file_name == "import.csv"
  end

  test "requires an importing user ID" do
    changeset = Upload.new(%RM.Account.User{}, "test/fixture/import.csv")

    refute changeset.valid?
    assert %{imported_by: [_]} = errors_on(changeset)
  end
end
