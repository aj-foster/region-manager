defmodule RM.Local.EventSettingsTest do
  use ExUnit.Case, async: true

  alias RM.FIRST.Event
  alias RM.Local.EventSettings

  describe "changeset/2" do
    test "requires the event and boolean settings" do
      changeset = EventSettings.changeset(%{})

      refute changeset.valid?

      assert errors_on(changeset) == %{
               event_id: ["can't be blank"],
               video_submission: ["can't be blank"],
               virtual: ["can't be blank"]
             }
    end

    test "requires a submission date when video submissions are enabled" do
      changeset =
        EventSettings.changeset(%{
          event_id: Ecto.UUID.generate(),
          video_submission: true,
          virtual: false
        })

      assert "can't be blank" in errors_on(changeset).video_submission_date
    end

    test "clears a submission date when video submissions are disabled" do
      changeset =
        EventSettings.changeset(%{
          event_id: Ecto.UUID.generate(),
          video_submission: false,
          video_submission_date: ~D[2025-01-01],
          virtual: false
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :video_submission_date) == nil
    end

    test "rejects a submission date after the event ends" do
      event = %Event{date_end: ~D[2025-04-10]}

      changeset =
        EventSettings.changeset(
          %EventSettings{event: event},
          %{
            event_id: Ecto.UUID.generate(),
            video_submission: true,
            video_submission_date: ~D[2025-04-11],
            virtual: false
          }
        )

      assert "must be before the end of the event" in errors_on(changeset).video_submission_date
    end

    test "accepts a submission date before the event ends" do
      event = %Event{date_end: ~D[2025-04-10]}

      changeset =
        EventSettings.changeset(
          %EventSettings{event: event},
          %{
            event_id: Ecto.UUID.generate(),
            video_submission: true,
            video_submission_date: ~D[2025-04-10],
            virtual: false,
            video_submission_pool: "league"
          }
        )

      assert changeset.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
