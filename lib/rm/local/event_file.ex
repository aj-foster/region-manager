defmodule RM.Local.EventFile do
  @moduledoc """
  File attachment and archive storage for uploaded PDF files
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  @doc false
  def acl(_version, {_file, _scope}) do
    :public_read
  end

  @doc false
  def filename(_version, {_file, scope}) do
    %RM.Local.EventAttachment{name: name} = scope
    name
  end

  @doc false
  def storage_dir(_version, {_file, scope}) do
    %RM.Local.EventAttachment{proposal_id: proposal_id} = scope
    "events/#{proposal_id}/"
  end

  @doc false
  def s3_object_headers(_version, _file_and_scope) do
    [content_type: "application/pdf"]
  end
end
