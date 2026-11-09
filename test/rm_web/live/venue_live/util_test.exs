defmodule RMWeb.VenueLive.UtilTest do
  use RMWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "state and province options use full names as their values" do
    for {country, name, abbreviation} <- [
          {"Canada", "Québec", "QC"},
          {"United States", "California", "CA"}
        ] do
      form =
        %RM.Local.Venue{country: country, state_province: name}
        |> Ecto.Changeset.change()
        |> Phoenix.Component.to_form()

      html =
        render_component(&RMWeb.VenueLive.Util.venue_form/1,
          prompt: "Save",
          venue_form: form
        )

      options =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("select[name='venue[state_province]'] option")

      assert [option] = Enum.filter(options, &(Floki.attribute(&1, "value") == [name]))
      assert Floki.text(option) == name
      assert Floki.attribute(option, "selected") != []
      refute Enum.any?(options, &(Floki.attribute(&1, "value") == [abbreviation]))
    end
  end
end
