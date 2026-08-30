defmodule RM.Email.Renderer do
  @moduledoc """
  Renders Markdown email previews using local template assets.
  """
  @behaviour Keila.Mailings.Renderer.BodyRenderer

  alias Keila.Mailings.Renderer.Input
  alias Keila.Templates.{Css, Html}

  import Keila.Mailings.Renderer.LiquidRenderer

  @html_template_path Path.expand("../../../priv/email/hybrid.html.liquid", __DIR__)
  @default_css_path Path.expand("../../../priv/email/default.css", __DIR__)

  @external_resource @html_template_path
  @external_resource @default_css_path

  @html_template File.read!(@html_template_path) |> Solid.parse!()
  @styles File.read!(@default_css_path) |> Css.parse!()

  @default_signature """
  This _FIRST_ Tech Challenge region uses [Region Manager](https://ftcregion.com) to send messages.

  [Unsubscribe]({{ unsubscribe_link }})
  """

  @impl true
  def render(output, %Input{} = input, assigns) do
    main_content = input.text_body || ""
    styles = merge_styles(input.template)

    embedded_css =
      styles
      |> Enum.filter(fn {selector, _} -> selector in embedded_styles() end)
      |> Css.encode()

    signature = get_signature(assigns)

    with {:ok, assigns} <- render_signature_to_assigns(assigns, signature),
         {:ok, assigns} <- render_main_content_to_assigns(assigns, main_content),
         {:ok, html_body} <- render_body(Map.put(assigns, "embedded_css", embedded_css)) do
      html_body = apply_styles!(html_body, styles)
      text_body = build_text_body(assigns)

      %{output | text_body: text_body, html_body: html_body}
    else
      {:error, reason} ->
        %{output | text_body: reason, errors: [reason | output.errors]}
    end
  end

  @spec merge_styles(Keila.Templates.Template.t() | nil) :: Css.t()
  def merge_styles(template)

  def merge_styles(%{styles: styles}) when is_list(styles) do
    styles()
    |> Css.merge(styles)
    |> apply_style_aliases()
  end

  def merge_styles(%{styles: styles}) when is_binary(styles) do
    styles()
    |> Css.merge(Css.parse!(styles))
    |> apply_style_aliases()
  end

  def merge_styles(_) do
    styles()
    |> apply_style_aliases()
  end

  def styles do
    @styles
  end

  def embedded_styles do
    [".email-bg"]
  end

  @spec apply_style_aliases(Css.t()) :: Css.t()
  def apply_style_aliases(styles) do
    aliases()
    |> Enum.reduce(styles, fn
      {source, target, properties}, styles ->
        case List.keyfind(styles, source, 0) do
          {^source, source_properties} ->
            filtered = Enum.filter(source_properties, fn {prop, _} -> prop in properties end)
            Css.merge(styles, [{target, filtered}])

          nil ->
            styles
        end

      {source, target}, styles ->
        case List.keyfind(styles, source, 0) do
          {^source, properties} -> Css.merge(styles, [{target, properties}])
          nil -> styles
        end
    end)
  end

  defp render_signature_to_assigns(assigns, signature) do
    case render_liquid_and_markdown(signature, assigns) do
      {:ok, signature_text, signature_html} ->
        {:ok,
         assigns
         |> Map.put("signature_text", signature_text)
         |> Map.put("signature_html", signature_html)}

      {:error, reason} ->
        {:error, "Error processing signature: " <> reason}
    end
  end

  defp get_signature(assigns) do
    case assigns["signature"] do
      empty when empty in [nil, ""] -> @default_signature
      signature -> signature
    end
  end

  defp render_main_content_to_assigns(assigns, main_content) do
    case render_liquid_and_markdown(main_content, assigns) do
      {:ok, main_text, main_html} ->
        {:ok,
         assigns
         |> Map.put("main_text", main_text)
         |> Map.put("main_html", main_html)
         |> Map.put("html_body_class", "keila--markdown-campaign")}

      {:error, reason} ->
        {:error, "Error processing main content: " <> reason}
    end
  end

  defp render_body(assigns) do
    render_liquid(@html_template, assigns)
  end

  defp apply_styles!(html_body, styles) do
    html_body
    |> Html.parse_document!()
    |> Html.apply_email_markup()
    |> Html.apply_inline_styles(styles, ignore_inherit: true)
    |> Html.to_document()
  end

  defp build_text_body(assigns) do
    user_signature =
      if user_signature = assigns["campaign"]["data"]["email_signature_text"] do
        "\n\n" <> user_signature
      else
        ""
      end

    assigns["main_text"] <> user_signature <> "\n\n--  \n" <> assigns["signature_text"]
  end

  defp aliases do
    [
      {"#content", ".stack-column > table", ["color", "font-family"]},
      {"#content", ".block>td", ["line-height"]}
    ]
  end

  # Analogue to `Keila.Mailings.Renderer` with customization

  alias Keila.Contacts
  alias Keila.Contacts.Contact
  alias Keila.Templates.Template
  alias Keila.Mailings.Renderer.Input
  alias Keila.Mailings.Renderer.Output
  import Keila.Mailings.Renderer.LiquidRenderer

  @doc """
  Renders an `Input` into an `Output` (subject + bodies).

  If an error occurred during rendering, the output stuct sets `valid?` to `false`
  and adds error strings to `errors`. Invalid outputs must not be sent out as emails.

  For more details on the `Input` and `Output` data structures refer to the
  respective module documentation.
  """
  @spec render(Input.t()) :: Output.t()
  def render(%Input{} = input) do
    assigns = build_assigns(input)

    %Output{}
    |> render_subject(input, assigns)
    |> render(input, assigns)
    |> then(fn output ->
      valid? = output.valid? and Enum.empty?(output.errors)
      errors = Enum.reverse(output.errors)
      %{output | valid?: valid?, errors: errors}
    end)
  rescue
    e ->
      %Output{valid?: false, errors: ["Unexpected render error: #{Exception.message(e)}"]}
  end

  defp build_assigns(input) do
    input.assigns
    |> put_template_assigns(input.template)
    |> Map.put_new("contact", contact_assigns(input))
    # TODO
    |> Map.put_new("assets_url", "/")
    |> process_assigns()
  end

  defp put_template_assigns(assigns, %Template{assigns: template_assigns = %{}}),
    do: Map.merge(template_assigns, assigns)

  defp put_template_assigns(assigns, _), do: assigns

  defp contact_assigns(%Input{contact: contact = %Contact{}}) do
    contact
    |> process_assigns()
    |> Map.put("display_name", Contacts.display_name(contact))
  end

  defp contact_assigns(%Input{recipient_email: email, recipient_name: name}),
    do: %{"email" => email, "display_name" => name, "data" => %{}}

  defp render_subject(output, input, assigns) do
    case render_liquid(input.subject || "", assigns) do
      {:ok, rendered} ->
        %{output | subject: rendered}

      {:error, error} ->
        %{output | subject: input.subject, errors: [error | output.errors]}
    end
  end
end
