defmodule RMWeb.RegionLive.Teams do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  alias RM.Import

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.preload(teams: [:league])

    socket
    |> assign(region: region)
    |> allow_upload(:team_data,
      accept: ["text/csv"],
      auto_upload: true,
      max_file_size: 1024 * 1024,
      progress: &handle_progress/3
    )
    |> assign(
      import_errors: [],
      import_status: :none
    )
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("import_change", _params, socket) do
    case socket.assigns[:uploads].team_data do
      %{entries: [%{valid?: false} = entry]} = upload ->
        socket
        |> assign(
          import_errors: upload_errors(upload, entry),
          import_status: :error
        )
        |> noreply()

      _else ->
        noreply(socket)
    end
  end

  def handle_event("import_submit", _params, socket) do
    noreply(socket)
  end

  @doc false
  defp handle_progress(upload, entry, socket)

  defp handle_progress(:team_data, entry, socket) do
    cond do
      entry.done? ->
        user = socket.assigns[:current_user]

        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          Import.import_from_team_info_tableau_export(user, path)
          {:ok, path}
        end)

        socket
        |> assign(import_status: :done)
        |> noreply()

      entry.cancelled? ->
        socket
        |> assign(import_status: :cancelled)
        |> noreply()

      :else ->
        socket
        |> assign(import_status: :in_progress)
        |> noreply()
    end
  end

  #
  # Template Helpers
  #

  @spec upload_error_to_string(atom) :: String.t()
  defp upload_error_to_string(:too_large), do: "Provided file is too large"
  defp upload_error_to_string(:not_accepted), do: "Please select a .csv file"
  defp upload_error_to_string(:external_client_failure), do: "Something went terribly wrong"
end
