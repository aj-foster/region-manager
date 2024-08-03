defmodule RM.Local.EventBatch do
  @moduledoc """
  Provides XLSX export of event proposals in a format accepted by FIRST
  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Elixlsx.Workbook
  alias Elixlsx.Sheet
  alias RM.FIRST.League
  alias RM.FIRST.Region
  alias RM.Local.EventProposal
  alias RM.Local.EventSubmission

  @batch_filename "EventRequests.xlsx"

  @typedoc "Generated batch event submission"
  @type t :: %__MODULE__{
          file: String.t(),
          generated_at: DateTime.t(),
          generated_by: Ecto.UUID.t()
        }

  @required_fields [:id, :generated_at, :generated_by]

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "event_batches" do
    field :file, EventSubmission.Type
    field :generated_at, :utc_datetime_usec
    field :generated_by, Ecto.UUID
  end

  @doc """
  Generate a new Batch Create spreadsheet based on the given event proposals

  ## Options

    * `id`: ID (presumably a UUID) to use in the workbook. Should be unique across all submissions.

  """
  @spec new(Region.t(), [EventProposal.t()]) :: {:ok, {charlist, binary}} | {:error, any}
  @spec new(Region.t(), [EventProposal.t()], keyword) :: {:ok, {charlist, binary}} | {:error, any}
  def new(region, proposals, opts \\ []) do
    id = opts[:id] || Ecto.UUID.generate()

    sheet =
      proposals
      |> Enum.with_index(3)
      |> Enum.reduce(base_sheet(region, id), &add_event_row/2)

    %Workbook{sheets: [sheet]}
    |> Elixlsx.write_to_memory(@batch_filename)
  end

  @doc """
  Save a generated event batch submission file
  """
  @spec save(Ecto.UUID.t(), binary, RM.Account.User.t()) :: Changeset.t(t)
  def save(id, workbook, user) do
    params = %{
      id: id,
      generated_at: DateTime.utc_now(),
      generated_by: user.id
    }

    %__MODULE__{}
    |> Changeset.cast(params, @required_fields)
    |> cast_file(workbook)
    |> Changeset.validate_required(@required_fields)
  end

  @spec cast_file(Changeset.t(%__MODULE__{}), String.t()) :: Changeset.t(%__MODULE__{})
  defp cast_file(changeset, workbook) do
    scope = Changeset.apply_changes(changeset)

    Changeset.cast(
      changeset,
      %{file: {%{filename: scope.id, binary: workbook}, scope}},
      [:file]
    )
  end

  #
  # Base Sheet
  #

  @a1_sentinel "3"
  @a2_message """
  This sheet was automatically generated by Region Manager, an application developed to assist PDPs in managing events. If something is incorrect with this data, please reach out to first@aj-foster.com.
  """
  @row_2_header_opts [align_vertical: :center, bg_color: "#F57E25", size: 11]
  @row_3_header_opts [
    align_horizontal: :center,
    bg_color: "#4472C4",
    bold: true,
    font: "Calibri",
    size: 11
  ]

  @spec base_sheet(Region.t(), Ecto.UUID.t()) :: Sheet.t()
  defp base_sheet(region, id) do
    Sheet.with_name("Events")
    |> Sheet.set_cell("A1", @a1_sentinel)
    |> Sheet.set_cell("B1", region.metadata.code_batch_country)
    |> Sheet.set_cell("C1", id)
    |> Sheet.set_cell("D1", region.current_season + 1)
    |> Sheet.set_cell("E1", String.upcase(region.code))
    |> Sheet.set_cell("A2", @a2_message, @row_2_header_opts)
    |> Sheet.set_cell("A3", "Event Type", @row_3_header_opts)
    |> Sheet.set_cell("B3", "Event Style", @row_3_header_opts)
    |> Sheet.set_cell("C3", "League", @row_3_header_opts)
    |> Sheet.set_cell("D3", "Event Name", @row_3_header_opts)
    |> Sheet.set_cell("E3", "Start Date\n(mm/dd/yyyy)", @row_3_header_opts)
    |> Sheet.set_cell("F3", "End Date\n(mm/dd/yyyy)", @row_3_header_opts)
    |> Sheet.set_cell("G3", "State / Province", @row_3_header_opts)
    |> Sheet.set_cell("H3", "City", @row_3_header_opts)
    |> Sheet.set_cell("I3", "Timezone", @row_3_header_opts)
    |> Sheet.set_cell("J3", "Venue", @row_3_header_opts)
    |> Sheet.set_cell("K3", "Street Address", @row_3_header_opts)
    |> Sheet.set_cell("L3", "Street Address Line 2", @row_3_header_opts)
    |> Sheet.set_cell("M3", "Postal Code", @row_3_header_opts)
    |> Sheet.set_cell("N3", "Venue Website", @row_3_header_opts)
    |> Sheet.set_cell("O3", "Capacity", @row_3_header_opts)
    |> Sheet.set_cell("P3", "Reserved\nCapacity", @row_3_header_opts)
    |> Sheet.set_cell("Q3", "Event Website", @row_3_header_opts)
    |> Sheet.set_cell("R3", "Live Stream URL", @row_3_header_opts)
    |> Sheet.set_cell("S3", "Contact First Name", @row_3_header_opts)
    |> Sheet.set_cell("T3", "Contact Last Name", @row_3_header_opts)
    |> Sheet.set_cell("U3", "Contact Phone", @row_3_header_opts)
    |> Sheet.set_cell("V3", "Contact Email", @row_3_header_opts)
    |> Sheet.set_cell("W3", "Event Description (Public)", @row_3_header_opts)
    |> Sheet.set_cell("X3", "Event Notes (Internal)", @row_3_header_opts)
    |> Sheet.set_cell("Y3", "Request-Specific Comments/Notes", @row_3_header_opts)
    |> Map.put(:merge_cells, [{"A2", "J2"}])
    |> Map.put(:col_widths, column_widths())
    |> Sheet.set_row_height(2, 60)
    |> Sheet.set_row_height(3, 30)
  end

  @column_widths [
    "23.9375",
    "15.4375",
    "39.81640625",
    "31.22265625",
    "15.265625",
    "15.265625",
    "21.5078125",
    "21.5078125",
    "21.5078125",
    "21.5078125",
    "31.22265625",
    "31.22265625",
    "13.25",
    "21.5078125",
    "10.01171875",
    "10.66015625",
    "21.5078125",
    "21.5078125",
    "21.03515625",
    "20.65625",
    "16.17578125",
    "16.65234375",
    "31.22265625",
    "31.22265625",
    "40.9375"
  ]

  @spec column_widths :: %{pos_integer => String.t()}
  defp column_widths do
    @column_widths
    |> Enum.with_index(1)
    |> Map.new(fn {width, col} -> {col, width} end)
  end

  #
  # Event Rows
  #

  @spec add_event_row({EventProposal.t(), pos_integer}, Sheet.t()) :: Sheet.t()
  defp add_event_row({proposal, row}, sheet) do
    sheet
    |> Sheet.set_at(row, 0, event_type(proposal))
    |> Sheet.set_at(row, 1, event_style(proposal))
    |> Sheet.set_at(row, 2, league(proposal))
    |> Sheet.set_at(row, 3, proposal.name)
    |> Sheet.set_at(row, 4, Calendar.strftime(proposal.date_start, "%m/%d/%Y"))
    |> Sheet.set_at(row, 5, Calendar.strftime(proposal.date_end, "%m/%d/%Y"))
    |> Sheet.set_at(row, 6, proposal.venue.state_province || "")
    |> Sheet.set_at(row, 7, proposal.venue.city)
    |> Sheet.set_at(row, 8, proposal.venue.timezone)
    |> Sheet.set_at(row, 9, proposal.venue.name)
    |> Sheet.set_at(row, 10, proposal.venue.address || "")
    |> Sheet.set_at(row, 11, proposal.venue.address_2 || "")
    |> Sheet.set_at(row, 12, proposal.venue.postal_code || "")
    |> Sheet.set_at(row, 13, proposal.venue.website || "")
    |> Sheet.set_at(row, 14, proposal.registration_settings.team_limit || "")
    |> Sheet.set_at(row, 15, "")
    |> Sheet.set_at(row, 16, proposal.website || "")
    |> Sheet.set_at(row, 17, proposal.live_stream_url || "")
    |> Sheet.set_at(row, 18, contact_first_name(proposal))
    |> Sheet.set_at(row, 19, contact_last_name(proposal))
    |> Sheet.set_at(row, 20, proposal.contact.phone || "")
    |> Sheet.set_at(row, 21, proposal.contact.email || "")
    |> Sheet.set_at(row, 22, proposal.description || "")
    |> Sheet.set_at(row, 23, "")
    |> Sheet.set_at(row, 24, "")
  end

  @spec event_type(EventProposal.t()) :: String.t()
  defp event_type(%EventProposal{type: :scrimmage}), do: "SCRIMMAGE"
  defp event_type(%EventProposal{type: :league_meet}), do: "LEAGUE_MEET"
  defp event_type(%EventProposal{type: :qualifier}), do: "QUALIFIER"
  defp event_type(%EventProposal{type: :league_tournament}), do: "LEAGUE_TOURNAMENT"
  defp event_type(%EventProposal{type: :super_qualifier}), do: "SUPER_QUALIFIER"
  defp event_type(%EventProposal{type: :regional_championship}), do: "CHAMPIONSHIP"
  defp event_type(%EventProposal{type: :off_season}), do: "OFF_SEASON"
  defp event_type(%EventProposal{type: :kickoff}), do: "KICKOFF"
  defp event_type(%EventProposal{type: :workshop}), do: "WORKSHOP"
  defp event_type(%EventProposal{type: :demo}), do: "DEMO"
  defp event_type(%EventProposal{type: :volunteer}), do: "VOLUNTEER"
  defp event_type(%EventProposal{type: :practice}), do: "PRACTICE"

  @spec event_style(EventProposal.t()) :: String.t()
  defp event_style(%EventProposal{format: :traditional}), do: "TRADITIONAL"
  defp event_style(%EventProposal{format: :hybrid}), do: "HYBRID"
  defp event_style(%EventProposal{format: :remote}), do: "REMOTE"

  # TODO: Ensure full names are used in the future
  @spec league(EventProposal.t()) :: String.t()
  defp league(%EventProposal{league: nil}), do: ""
  defp league(%EventProposal{league: %League{code: code, name: name}}), do: "[#{code}] #{name}"

  @spec contact_first_name(EventProposal.t()) :: String.t()
  defp contact_first_name(%EventProposal{contact: %EventProposal.Contact{name: nil}}), do: ""
  defp contact_first_name(%EventProposal{contact: %EventProposal.Contact{name: ""}}), do: ""

  defp contact_first_name(%EventProposal{contact: %EventProposal.Contact{name: name}}) do
    case String.split(name, " ", trim: true) do
      [first | _more] -> first
      _else -> ""
    end
  end

  @spec contact_last_name(EventProposal.t()) :: String.t()
  defp contact_last_name(%EventProposal{contact: %EventProposal.Contact{name: nil}}), do: ""
  defp contact_last_name(%EventProposal{contact: %EventProposal.Contact{name: ""}}), do: ""

  defp contact_last_name(%EventProposal{contact: %EventProposal.Contact{name: name}}) do
    case String.split(name, " ", trim: true) do
      [_first | rest] -> Enum.join(rest, " ")
      _else -> ""
    end
  end
end