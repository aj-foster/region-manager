defmodule RMWeb.ICSTest do
  use ExUnit.Case, async: true

  alias RM.FIRST.Event
  alias RM.Local.EventProposal
  alias RM.Local.Venue

  test "renders event properties, escapes text, and uses an exclusive end date" do
    event = %Event{
      id: "event-id",
      name: "Robotics; Expo, Day 1",
      type: :scrimmage,
      date_start: ~D[2026-03-14],
      date_end: ~D[2026-03-15],
      updated_at: ~U[2026-01-02 03:04:05Z],
      website: "https://example.test/event",
      live_stream_url: "https://example.test/live",
      proposal: nil,
      location: %Event.Location{
        venue: "Hall A",
        address: "1 Main St",
        city: "Boston",
        state_province: "MA",
        country: "USA"
      }
    }

    calendar = RMWeb.ICS.render("Spring, Events", [event], &"https://example.test/#{&1.id}")

    assert calendar =~ "X-WR-CALNAME:Spring\\, Events\r\n"
    assert calendar =~ "UID:event-id@region-manager\r\n"
    assert calendar =~ "DTSTAMP:20260102T030405Z\r\n"
    assert calendar =~ "SUMMARY:Robotics\\; Expo\\, Day 1\r\n"
    assert calendar =~ "DTSTART;VALUE=DATE:20260314\r\n"
    assert calendar =~ "DTEND;VALUE=DATE:20260316\r\n"
    assert calendar =~ "LOCATION:Hall A\\, 1 Main St\\, Boston\\, MA\\, USA\r\n"

    unfolded = String.replace(calendar, "\r\n ", "")

    assert unfolded =~
             "DESCRIPTION:Scrimmage\\nhttps://example.test/live\\nhttps://example.test/event\r\n"

    assert String.replace(calendar, "\r\n ", "") =~ "URL:https://example.test/event-id\r\n"
    assert String.ends_with?(calendar, "END:VCALENDAR\r\n")
  end

  test "uses proposal details, venue notes, and the most recently modified timestamp" do
    event = %Event{
      id: "proposal-event",
      name: "Proposed event",
      type: :qualifier,
      date_start: ~D[2026-04-01],
      date_end: ~D[2026-04-01],
      updated_at: ~U[2026-01-01 00:00:00Z],
      live_stream_url: "https://event.test/live",
      website: "https://event.test",
      proposal: %EventProposal{
        updated_at: ~U[2026-02-03 04:05:06Z],
        description: "Doors open; bring a badge",
        live_stream_url: nil,
        website: " ",
        venue: %Venue{notes: "Use the side entrance"}
      }
    }

    calendar = RMWeb.ICS.render("Events", [event], fn _ -> nil end)

    assert calendar =~ "DTSTAMP:20260203T040506Z\r\n"
    assert calendar =~ "LAST-MODIFIED:20260203T040506Z\r\n"

    unfolded = String.replace(calendar, "\r\n ", "")

    assert unfolded =~
             "DESCRIPTION:Qualifier\\nDoors open\\; bring a badge\\nhttps://event.test/live\\nhttps://event.test\\nUse the side entrance\r\n"
  end

  test "folds long lines without splitting UTF-8 graphemes" do
    event = %Event{
      id: "long-event",
      name: String.duplicate("é", 50),
      type: :scrimmage,
      date_start: ~D[2026-05-01],
      date_end: ~D[2026-05-01],
      updated_at: ~U[2026-01-01 00:00:00Z],
      proposal: nil
    }

    lines = RMWeb.ICS.render("Events", [event], fn _ -> nil end) |> String.split("\r\n")
    summary_index = Enum.find_index(lines, &String.starts_with?(&1, "SUMMARY:"))
    [first_summary_line, continuation] = Enum.slice(lines, summary_index, 2)

    assert String.starts_with?(continuation, " ")

    assert first_summary_line <> String.trim_leading(continuation) ==
             "SUMMARY:" <> String.duplicate("é", 50)

    assert Enum.all?(lines, &(byte_size(&1) <= 75))
    assert Enum.all?(lines, &String.valid?/1)
  end
end
