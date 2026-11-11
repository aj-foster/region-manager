defmodule RMWeb.ProposalLive.NewTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Account.Region, as: UserRegion
  alias RM.Local.EventProposal
  alias RM.Repo

  setup %{conn: conn} do
    region = Factory.insert(:region)
    venue = Factory.insert(:venue, region: region, league: nil)
    user = Factory.insert(:user)
    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    path = "/s/#{region.current_season}/r/#{region.abbreviation}/proposals/new"

    %{conn: conn, path: path, region: region, user: user, venue: venue}
  end

  test "creates a proposal with uploaded PDFs", context do
    {:ok, view, _html} = live(context.conn, context.path)
    select_venue(view, context.venue)
    upload_pdf(view, "program.pdf")
    upload_pdf(view, "schedule.pdf")

    assert {:error, {:live_redirect, _}} = submit(view)

    proposal = Repo.get_by!(EventProposal, name: "Test Event") |> Repo.preload(:attachments)
    cleanup_attachments(proposal)
    assert Enum.sort(Enum.map(proposal.attachments, & &1.name)) == ["program.pdf", "schedule.pdf"]
    assert Enum.all?(proposal.attachments, &(&1.uploaded_by == context.user.id))
    assert Enum.all?(proposal.attachments, &(&1.type == :program))
    assert Enum.all?(proposal.attachments, &File.exists?(attachment_path(&1)))
  end

  test "uploads attachments when creating a proposal for a published event", context do
    event =
      Factory.insert(:first_event, region: context.region)
      |> Factory.with_event_settings()

    {:ok, view, _html} = live(context.conn, context.path <> "?event=#{event.id}")
    select_venue(view, context.venue)
    upload_pdf(view, "program.pdf")

    assert {:error, {:live_redirect, _}} = submit(view, retroactive: true)
    proposal = Repo.get_by!(EventProposal, first_event_id: event.id) |> Repo.preload(:attachments)
    cleanup_attachments(proposal)
    assert [%{name: "program.pdf"} = attachment] = proposal.attachments
    assert File.exists?(attachment_path(attachment))
  end

  test "creates a league proposal with an attachment", context do
    league = Factory.insert(:league, region: context.region) |> Factory.with_league_settings()
    venue = Factory.insert(:venue, region: context.region, league: league)

    path =
      "/s/#{context.region.current_season}/r/#{context.region.abbreviation}/l/#{league.code}/proposals/new"

    {:ok, view, _html} = live(context.conn, path)
    select_venue(view, venue)
    upload_pdf(view, "program.pdf")

    assert {:error, {:live_redirect, _}} = submit(view, league: true)
    proposal = Repo.get_by!(EventProposal, league_id: league.id) |> Repo.preload(:attachments)
    cleanup_attachments(proposal)
    assert [%{name: "program.pdf"}] = proposal.attachments
  end

  test "keeps uploaded files while correcting validation errors", context do
    {:ok, view, _html} = live(context.conn, context.path)
    upload_pdf(view, "program.pdf")
    assert submit(view) =~ "program.pdf"
    refute Repo.get_by(EventProposal, name: "Test Event")

    select_venue(view, context.venue)
    assert {:error, {:live_redirect, _}} = submit(view)
    proposal = Repo.get_by!(EventProposal, name: "Test Event") |> Repo.preload(:attachments)
    cleanup_attachments(proposal)
    assert [%{name: "program.pdf"}] = proposal.attachments
  end

  test "cancels a selected attachment and permits creation without one", context do
    {:ok, view, _html} = live(context.conn, context.path)
    select_venue(view, context.venue)
    upload_pdf(view, "program.pdf")
    view |> element("button[aria-label=cancel]") |> render_click()
    refute render(view) =~ "program.pdf"
    assert {:error, {:live_redirect, _}} = submit(view)
    proposal = Repo.get_by!(EventProposal, name: "Test Event") |> Repo.preload(:attachments)
    assert proposal.attachments == []
  end

  test "rejects files that are not PDFs", context do
    {:ok, view, _html} = live(context.conn, context.path)

    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: "notes.txt", content: "notes", type: "text/plain"}
      ])

    assert {:error, _} = render_upload(upload, "notes.txt")
    assert render(view) =~ "Please select a .pdf file"
    assert has_element?(view, "button[type=submit][disabled]", "Propose Event")
  end

  test "rejects PDFs larger than 10 MiB", context do
    {:ok, view, _html} = live(context.conn, context.path)

    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{
          name: "large.pdf",
          content: :binary.copy("x", 10 * 1024 * 1024 + 1),
          type: "application/pdf"
        }
      ])

    assert {:error, _} = render_upload(upload, "large.pdf")
    assert render(view) =~ "Provided file is too large"
    assert has_element?(view, "button[type=submit][disabled]", "Propose Event")
  end

  test "rejects more than four files at once", context do
    {:ok, view, _html} = live(context.conn, context.path)

    entries =
      for number <- 1..5 do
        %{name: "#{number}.pdf", content: "PDF", type: "application/pdf"}
      end

    upload = file_input(view, "#event-proposal-form", :attachment, entries)
    assert render_upload(upload, "1.pdf") =~ "Please select up to 4 files at once"
    assert render(view) =~ "Please select up to 4 files at once"
    assert has_element?(view, "button[type=submit][disabled]", "Propose Event")
  end

  test "prevents submission while a file is uploading", context do
    {:ok, view, _html} = live(context.conn, context.path)
    select_venue(view, context.venue)

    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: "program.pdf", content: :binary.copy("x", 100), type: "application/pdf"}
      ])

    assert render_upload(upload, "program.pdf", 50) =~ "program.pdf"
    assert has_element?(view, "button[type=submit][disabled]", "Propose Event")
    refute Repo.get_by(EventProposal, name: "Test Event")
    assert render_upload(upload, "program.pdf", 50) =~ "program.pdf"
    assert {:error, {:live_redirect, _}} = submit(view)
    proposal = Repo.get_by!(EventProposal, name: "Test Event") |> Repo.preload(:attachments)
    cleanup_attachments(proposal)
  end

  test "the existing edit form continues to reject non-PDF files", context do
    proposal = Factory.insert(:event_proposal, region: context.region, venue: context.venue)

    path =
      "/s/#{context.region.current_season}/r/#{context.region.abbreviation}/p/#{proposal.id}/edit"

    {:ok, view, _html} = live(context.conn, path)

    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: "notes.txt", content: "notes", type: "text/plain"}
      ])

    assert {:error, _} = render_upload(upload, "notes.txt")
    assert render(view) =~ "Please select a .pdf file"
  end

  defp select_venue(view, venue) do
    view |> form("#event-venue-form", %{"venue" => venue.id}) |> render_change()
  end

  defp upload_pdf(view, name) do
    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: name, content: "%PDF-1.4 test", type: "application/pdf"}
      ])

    assert render_upload(upload, name) =~ name
  end

  defp submit(view, opts \\ []) do
    today = Date.to_iso8601(Date.utc_today())

    params = %{
      name: "Test Event",
      type: if(opts[:league], do: "league_meet", else: "qualifier"),
      format: "traditional",
      date_start: today,
      date_end: today,
      contact: %{name: "Test Director", email: "director@example.com", phone: "1234567890"}
    }

    params =
      if opts[:retroactive] do
        params
      else
        Map.put(params, :registration_settings, %{enabled: "false"})
      end

    view
    |> form("#event-proposal-form", event_proposal: params)
    |> render_submit()
  end

  defp attachment_path(attachment) do
    Path.join(["priv/static/waffle/events", attachment.proposal_id, attachment.name])
  end

  defp cleanup_attachments(proposal) do
    on_exit(fn ->
      Enum.each(proposal.attachments, &File.rm(attachment_path(&1)))
      File.rmdir(Path.join("priv/static/waffle/events", proposal.id))
    end)
  end
end
