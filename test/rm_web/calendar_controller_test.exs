defmodule RMWeb.CalendarControllerTest do
  use RMWeb.ConnCase

  setup :create_region

  describe "GET /calendar/r/:region/events.ics" do
    test "includes events across seasons and excludes removed and division events", %{
      conn: conn,
      region: region
    } do
      Factory.insert(:first_event,
        code: "OLD",
        date_start: ~D[2023-10-14],
        date_end: ~D[2023-10-15],
        name: "Old season event",
        region: region,
        season: 2023
      )

      changed_event =
        Factory.insert(:first_event,
          code: "NEW",
          date_start: ~D[2025-11-02],
          date_end: ~D[2025-11-02],
          region: region,
          season: 2025,
          name: "Changed; Event"
        )

      Factory.insert(:first_event,
        code: "REMOVED",
        region: region,
        removed_at: DateTime.utc_now()
      )

      Factory.insert(:first_event, code: "DIVISION", region: region, division_code: "D1")

      RM.Repo.update!(Ecto.Changeset.change(region, current_season: 2026))

      conn = get(conn, "/calendar/r/FL/events.ics")
      response = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["text/calendar; charset=utf-8"]
      assert response =~ "BEGIN:VCALENDAR\r\n"
      assert response =~ "SUMMARY:Old season event"
      assert response =~ "SUMMARY:Changed\\; Event"
      assert response =~ "DTSTART;VALUE=DATE:20251102"
      assert response =~ "DTEND;VALUE=DATE:20251103"
      refute response =~ "REMOVED"
      refute response =~ "DIVISION"

      uid =
        response
        |> String.split("BEGIN:VEVENT")
        |> Enum.find(&String.contains?(&1, "SUMMARY:Changed\\; Event"))
        |> then(fn event -> Regex.run(~r/UID:([^\r\n]+)/, event) end)
        |> List.last()

      RM.Repo.update!(
        Ecto.Changeset.change(changed_event,
          date_start: ~D[2025-11-03],
          date_end: ~D[2025-11-04],
          name: "Updated event"
        )
      )

      updated =
        build_conn()
        |> get("/calendar/r/FL/events.ics")
        |> response(200)

      assert updated =~ "UID:#{uid}"
      assert updated =~ "SUMMARY:Updated event"
      assert updated =~ "DTSTART;VALUE=DATE:20251103"
      assert updated =~ "DTEND;VALUE=DATE:20251105"
    end
  end

  describe "GET /calendar/r/:region/l/:league/events.ics" do
    test "tracks events by persistent league, preferring a linked proposal's league", %{
      conn: conn,
      region: region
    } do
      league = Factory.insert(:league, code: "FLOR", name: "Orlando Robotics", region: region)
      other_league = Factory.insert(:league, code: "TAMP", name: "Tampa Robotics", region: region)

      first_league =
        Factory.insert(:first_league,
          code: "FLOR",
          local_league: league,
          region: region,
          season: 2023
        )

      Factory.insert(:first_event,
        code: "LEAGUE-OLD",
        date_start: ~D[2023-12-01],
        date_end: ~D[2023-12-01],
        league: first_league,
        local_league: league,
        name: "Old league event",
        region: region,
        season: 2023
      )

      Factory.insert(:first_event,
        code: "CONFLICTING-MAPPING",
        league: first_league,
        local_league: other_league,
        name: "Conflicting mapping event",
        region: region,
        season: 2023
      )

      misclassified =
        Factory.insert(:first_event,
          code: "MISCLASSIFIED",
          league: first_league,
          name: "Misclassified event",
          region: region,
          season: 2023
        )

      Factory.insert(:event_proposal,
        first_event: misclassified,
        league: other_league,
        region: region
      )

      no_league =
        Factory.insert(:first_event,
          code: "NO-LEAGUE",
          league: first_league,
          name: "No league event",
          region: region
        )

      Factory.insert(:event_proposal,
        first_event: no_league,
        league: nil,
        region: region
      )

      conn = get(conn, "/calendar/r/FL/l/FLOR/events.ics")
      response = response(conn, 200)

      assert response =~ "SUMMARY:Old league event"
      refute response =~ "SUMMARY:Conflicting mapping event"
      refute response =~ "MISCLASSIFIED"
      refute response =~ "SUMMARY:No league event"

      region_response =
        build_conn()
        |> get("/calendar/r/FL/events.ics")
        |> response(200)

      assert region_response =~ "SUMMARY:No league event"
      assert region_response =~ "SUMMARY:Misclassified event"
    end
  end
end
