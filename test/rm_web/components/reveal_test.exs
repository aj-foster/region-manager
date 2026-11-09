defmodule RMWeb.RevealTest do
  use RMWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "param determines the hook, query parameter and command targets" do
    slot = [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]

    controlled =
      render_component(&RMWeb.CoreComponents.reveal/1,
        param: "details",
        title: "Controlled",
        show: true,
        inner_block: slot
      )

    assert controlled =~ ~s(phx-hook="QueryReveal")
    assert controlled =~ ~s(data-query-param="details")
    assert controlled =~ ~s(data-default-expanded="true")
    assert controlled =~ "query-reveal:toggle"
    assert controlled =~ "data-reveal-show"
    assert controlled =~ "data-reveal-hide"

    [toggle] = controlled |> Floki.parse_fragment!() |> Floki.find("#reveal-details-toggle")
    [show] = Floki.attribute(toggle, "data-reveal-show")
    [hide] = Floki.attribute(toggle, "data-reveal-hide")

    assert [
             ["remove_class", %{"names" => ["h-0"], "to" => "#reveal-details-contents"}],
             ["add_class", %{"names" => ["h-auto"], "to" => "#reveal-details-contents"}],
             ["add_class", %{"names" => ["rotate-180"], "to" => "#reveal-details-icon"}]
           ] = Jason.decode!(show)

    assert [
             ["remove_class", %{"names" => ["h-auto"], "to" => "#reveal-details-contents"}],
             ["add_class", %{"names" => ["h-0"], "to" => "#reveal-details-contents"}],
             ["remove_class", %{"names" => ["rotate-180"], "to" => "#reveal-details-icon"}]
           ] = Jason.decode!(hide)
  end
end
