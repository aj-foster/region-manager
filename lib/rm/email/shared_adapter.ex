defmodule RM.Email.SharedAdapter do
  use Keila.Mailings.SenderAdapters.Adapter
  use KeilaWeb.Gettext

  import Ecto.Changeset

  @impl true
  def name, do: "shared_ses"

  @impl true
  def schema_fields do
    []
  end

  @impl true
  def changeset(changeset, _params) do
    changeset
    |> change()
  end

  @impl true
  def to_swoosh_config(%{shared_sender: shared_sender}) do
    RM.Email.Adapter.to_swoosh_config(shared_sender)
  end

  @impl true
  def put_provider_options(email, %{shared_sender: shared_sender}) do
    RM.Email.Adapter.put_provider_options(email, shared_sender)
  end
end
