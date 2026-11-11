defmodule RMWeb.ProposalLive.Util do
  @moduledoc false

  import Phoenix.Component, only: [upload_errors: 1]
  import Phoenix.LiveView, only: [allow_upload: 3, consume_uploaded_entries: 3]

  alias Phoenix.LiveView.UploadConfig
  alias Phoenix.LiveView.UploadEntry

  def configure_attachment_upload(socket) do
    allow_upload(socket, :attachment,
      accept: ["application/pdf"],
      auto_upload: true,
      max_entries: 4,
      max_file_size: 10 * 1024 * 1024
    )
  end

  @spec upload_error?(%{attachment: %UploadConfig{}}) :: boolean
  def upload_error?(uploads) do
    upload_errors(uploads.attachment) != [] or
      Enum.any?(uploads.attachment.entries, &(not &1.valid?))
  end

  def upload_pending_or_error?(uploads) do
    upload_error?(uploads) or Enum.any?(uploads.attachment.entries, &(not &1.done?))
  end

  def save_attachments(socket, proposal) do
    consume_uploaded_entries(socket, :attachment, fn %{path: path},
                                                     %UploadEntry{client_name: name} ->
      params = %{
        "name" => name,
        "path" => path,
        "type" => "program",
        "user" => socket.assigns[:current_user]
      }

      case RM.Local.create_or_update_attachment(proposal, params) do
        {:ok, _attachment} -> {:ok, nil}
        {:error, _changeset} -> {:ok, name}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec upload_error_to_string(atom) :: String.t()
  def upload_error_to_string(:too_large), do: "Provided file is too large"
  def upload_error_to_string(:not_accepted), do: "Please select a .pdf file"
  def upload_error_to_string(:external_client_failure), do: "Something went terribly wrong"
  def upload_error_to_string(:too_many_files), do: "Please select up to 4 files at once"
end
