defmodule RM.Util.TypstTest do
  use ExUnit.Case, async: true

  test "renders a template with data into a PDF binary" do
    template = "= Hello #name"

    assert {:ok, <<"%PDF-", _rest::binary>>} =
             RM.Util.Typst.render_pdf(template, %{name: "Region Manager"})
  end

  test "renders a template using an external package" do
    template = """
    #import "@preview/cades:0.3.1": qr-code

    = Team registration

    #qr-code("https://example.com")
    """

    assert {:ok, <<"%PDF-", _rest::binary>>} = RM.Util.Typst.render_pdf(template)
  end
end
