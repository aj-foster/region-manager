defmodule RM.Util.Typst do
  @moduledoc """
  Render Typst templates to PDF binaries.

  The returned binary can be sent as a download or passed to the application's
  file storage workflows.
  """

  @type template :: String.t()
  @type data :: Typster.variables()
  @type render_options :: Typster.render_options()

  @doc """
  Render a Typst template with data for its variables.

  Typster options such as `:metadata`, `:package_paths`, and `:root_path` can be
  provided as the third argument.
  """
  @spec render_pdf(template(), data(), render_options()) ::
          {:ok, Typster.pdf_binary()} | {:error, String.t()}
  def render_pdf(template, data \\ %{}, opts \\ []) do
    Typster.render_pdf(template, Keyword.put(opts, :variables, data))
  end
end
