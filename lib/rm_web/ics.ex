defmodule RMWeb.ICS do
  @moduledoc false

  def render(name, events) do
    [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Region Manager//Event Calendar//EN",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      property("X-WR-CALNAME", name),
      Enum.map(events, &render_event/1),
      "END:VCALENDAR"
    ]
    |> List.flatten()
    |> Enum.map_join("", &"#{fold_line(&1)}\r\n")
  end

  defp render_event(event) do
    modified_at = event |> last_modified() |> timestamp()

    [
      "BEGIN:VEVENT",
      property("UID", "#{event.id}@region-manager"),
      property("DTSTAMP", modified_at),
      property("LAST-MODIFIED", modified_at),
      property("SUMMARY", event.name),
      property("DTSTART;VALUE=DATE", date(event.date_start)),
      property("DTEND;VALUE=DATE", date(Date.add(event.date_end, 1))),
      property("LOCATION", location(event.location)),
      property("DESCRIPTION", description(event)),
      property("URL", website(event)),
      "END:VEVENT"
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp description(%{proposal: %RM.Local.EventProposal{} = proposal} = event) do
    [
      RM.FIRST.Event.type_name(event.type),
      proposal.description,
      proposal.live_stream_url || event.live_stream_url
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  defp description(event) do
    [RM.FIRST.Event.type_name(event.type), event.live_stream_url]
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n")
  end

  defp website(%{proposal: %RM.Local.EventProposal{website: website}} = event) do
    if blank?(website), do: event.website, else: website
  end

  defp website(event), do: event.website

  defp last_modified(%{updated_at: event_updated_at, proposal: proposal}) do
    proposal_updated_at = if proposal, do: proposal.updated_at

    [event_updated_at, proposal_updated_at]
    |> Enum.reject(&is_nil/1)
    |> Enum.max_by(&DateTime.to_unix(&1, :microsecond))
  end

  defp location(nil), do: nil

  defp location(location) do
    [
      location.venue,
      location.address,
      location.city,
      location.state_province,
      location.country
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(", ")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp property(_name, nil), do: nil
  defp property(name, value), do: "#{name}:#{escape(to_string(value))}"

  defp escape(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\r\n", "\\n")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\n")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
  end

  defp date(date), do: Date.to_iso8601(date) |> String.replace("-", "")

  defp timestamp(datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp blank?(nil), do: true
  defp blank?(value), do: String.trim(value) == ""

  defp fold_line(line), do: fold_line(String.graphemes(line), 75, [])
  defp fold_line([], _limit, chunks), do: chunks |> Enum.reverse() |> Enum.join("\r\n ")

  defp fold_line(graphemes, limit, chunks) do
    {chunk, rest} = take_graphemes(graphemes, limit, [], 0)
    fold_line(rest, 74, [Enum.join(chunk) | chunks])
  end

  defp take_graphemes([], _limit, chunk, _size), do: {Enum.reverse(chunk), []}

  defp take_graphemes([grapheme | rest] = graphemes, limit, chunk, size) do
    grapheme_size = byte_size(grapheme)

    if size + grapheme_size > limit do
      {Enum.reverse(chunk), graphemes}
    else
      take_graphemes(rest, limit, [grapheme | chunk], size + grapheme_size)
    end
  end
end
