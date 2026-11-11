defmodule RMWeb.ProposalLive.EditTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Account.Region, as: UserRegion
  alias RM.Repo

  setup %{conn: conn} do
    region = Factory.insert(:region)
    venue = Factory.insert(:venue, region: region, league: nil)
    user = Factory.insert(:user)
    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

    proposal =
      Factory.insert(:event_proposal,
        region: region,
        venue: venue,
        type: :qualifier,
        registration_settings: %RM.Local.RegistrationSettings{enabled: false, pool: :all}
      )

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    path = "/s/#{region.current_season}/r/#{region.abbreviation}/p/#{proposal.id}/edit"
    {:ok, view, _html} = live(conn, path)

    on_exit(fn ->
      directory = Path.join("priv/static/waffle/events", proposal.id)
      File.rm(Path.join(directory, "program.pdf"))
      File.rm(Path.join(directory, "   "))
      File.rmdir(directory)
      File.rm(directory)
    end)

    %{view: view, proposal: proposal, user: user}
  end

  test "rejects submissions with invalid uploads before updating", %{
    view: view,
    proposal: proposal
  } do
    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: "notes.txt", content: "notes", type: "text/plain"}
      ])

    assert {:error, _} = render_upload(upload, "notes.txt")

    assert render_hook(view, "proposal_submit", %{"event_proposal" => %{"name" => "Updated"}}) =~
             "Please resolve attachment errors"

    assert Repo.reload!(proposal).name == proposal.name
  end

  test "rejects submissions while an upload is in progress", %{view: view, proposal: proposal} do
    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: "program.pdf", content: :binary.copy("x", 100), type: "application/pdf"}
      ])

    assert render_upload(upload, "program.pdf", 50) =~ "program.pdf"
    assert has_element?(view, "button[type=submit][disabled]", "Update Proposal")

    assert render_hook(view, "proposal_submit", %{"event_proposal" => %{"name" => "Updated"}}) =~
             "Please resolve attachment errors"

    assert Repo.reload!(proposal).name == proposal.name
    assert render_upload(upload, "program.pdf", 50) =~ "program.pdf"

    assert {:error, {:live_redirect, %{flash: flash}}} = submit(view)

    assert %{"info" => "Event proposal updated successfully"} =
             Phoenix.LiveView.Utils.verify_flash(@endpoint, flash)

    updated = Repo.reload!(proposal) |> Repo.preload(:attachments)
    assert updated.name == "Updated Event"
    assert [%{name: "program.pdf"}] = updated.attachments
  end

  test "reports attachment save failures after updating the proposal", %{
    view: view,
    proposal: proposal
  } do
    upload =
      file_input(view, "#event-proposal-form", :attachment, [
        %{name: "   ", content: "PDF", type: "application/pdf"}
      ])

    assert render_upload(upload, "   ") =~ "cloud-arrow-up"

    assert {:error, {:live_redirect, %{flash: flash}}} = submit(view)
    assert %{"error" => error} = Phoenix.LiveView.Utils.verify_flash(@endpoint, flash)
    assert error =~ "Event proposal updated, but these attachments could not be saved:"
    assert Repo.reload!(proposal).name == "Updated Event"
    assert Repo.preload(proposal, :attachments).attachments == []
  end

  defp submit(view) do
    view
    |> form("#event-proposal-form", event_proposal: %{name: "Updated Event"})
    |> render_submit()
  end
end
