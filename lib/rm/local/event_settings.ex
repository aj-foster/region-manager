defmodule RM.Local.EventSettings do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.Event
  alias RM.Local.RegistrationSettings
  alias RM.Repo

  @typedoc "Group of teams that can submit video awards for an event"
  @type award_pool :: :registered | :league | :region | :all
  @award_pools [:registered, :league, :region, :all]

  @typedoc "Settings for an event"
  @type t :: %__MODULE__{
          event: Event.t(),
          event_id: Ecto.UUID.t(),
          id: Ecto.UUID.t(),
          registration: RegistrationSettings.t(),
          video_submission: boolean,
          video_submission_date: Date.t(),
          video_submission_pool: award_pool,
          virtual: boolean
        }

  @required_fields [:event_id, :video_submission, :virtual]
  @optional_fields [:video_submission_date, :video_submission_pool]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_settings" do
    field :video_submission, :boolean
    field :video_submission_date, :date
    field :video_submission_pool, Ecto.Enum, values: @award_pools
    field :virtual, :boolean
    embeds_one :registration, RegistrationSettings, on_replace: :update

    belongs_to :event, Event
  end

  @doc """
  Default settings for a new event
  """
  @spec default_params(Event.t()) :: map
  def default_params(event) do
    event = Repo.preload(event, [:proposal, local_league: :settings])

    deadline_days =
      cond do
        event.proposal ->
          event.proposal.registration_settings.deadline_days

        event.local_league && event.local_league.settings ->
          event.local_league.settings.registration.deadline_days

        :else ->
          7
      end

    open_days =
      cond do
        event.proposal ->
          event.proposal.registration_settings.open_days

        event.local_league && event.local_league.settings ->
          event.local_league.settings.registration.open_days

        :else ->
          21
      end

    enabled =
      cond do
        event.proposal ->
          event.proposal.registration_settings.enabled

        event.local_league && event.local_league.settings ->
          event.local_league.settings.registration.enabled

        :else ->
          true
      end

    pool = if event.local_league, do: :league, else: :region

    %{
      event_id: event.id,
      video_submission: false,
      video_submission_date: nil,
      video_submission_pool: nil,
      virtual: false,
      registration: %RegistrationSettings{
        deadline_days: deadline_days,
        enabled: enabled,
        open_days: open_days,
        pool: pool,
        waitlist_pool: pool
      }
    }
  end

  @doc """
  Create a changeset to insert or update event settings
  """
  @spec changeset(map) :: Changeset.t(t)
  @spec changeset(%__MODULE__{}, map) :: Changeset.t(t)
  def changeset(settings \\ %__MODULE__{}, params) do
    settings
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.validate_required(@required_fields)
    |> Changeset.cast_embed(:registration)
    |> validate_video_submission_date()
  end

  @spec validate_video_submission_date(Changeset.t(t)) :: Changeset.t(t)
  defp validate_video_submission_date(changeset) do
    if Changeset.get_field(changeset, :video_submission) do
      changeset
      |> Changeset.validate_required([:video_submission_date])
      |> Changeset.validate_change(:video_submission_date, fn :video_submission_date, date ->
        cond do
          not is_struct(changeset.data.event, Event) ->
            []

          Date.after?(date, changeset.data.event.date_end) ->
            [video_submission_date: "must be before the end of the event"]

          :else ->
            []
        end
      end)
    else
      Changeset.put_change(changeset, :video_submission_date, nil)
    end
  end
end
