defmodule RMWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as modals, tables, and
  forms. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Visual foreground for page content
  """
  attr :class, :string, default: nil, doc: "additional classes"
  attr :spaced, :boolean, default: false, doc: "easily add bottom margin"
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={[
      "bg-white border border-slate-200 px-6 py-4 rounded shadow",
      @spaced && "mb-8",
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Visual foreground for page content that also acts as a link
  """
  attr :class, :string, default: nil, doc: "additional classes"
  attr :rest, :global, include: ~w(href navigate patch)
  slot :inner_block, required: true

  def link_card(assigns) do
    ~H"""
    <.link class={["bg-white border border-slate-200 px-6 py-4 rounded shadow", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Small tag for metadata following an entity

  ## Examples

      <p><%= team.title %><.tag><%= team.league %></p>

  """
  attr :class, :string, default: nil, doc: "additional classes"
  slot :inner_block, required: true

  def tag(assigns) do
    ~H"""
    <span class={["border border-1 font-semibold px-1 py-0.5 rounded text-xs", @class]}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  Page or section title
  """
  attr :class, :string, default: nil, doc: "additional classes to apply"
  attr :flush, :boolean, default: false, doc: "when true, remove all margin"
  slot :inner_block, required: true

  def title(assigns) do
    ~H"""
    <h2 class={[
      "font-title italic uppercase",
      if(not @flush, do: "mb-4 ml-6"),
      @class
    ]}>
      <%= render_slot(@inner_block) %>
    </h2>
    """
  end

  @doc """
  Visual warning with left-side icon and arbitrary contents
  """
  attr :class, :string, default: nil, doc: "additional classes to apply"
  slot :inner_block, required: true

  def warning(assigns) do
    ~H"""
    <div class={[
      "bg-orange-100 border border-orange-400 flex gap-3 items-center justify-start px-4 py-2 rounded text-sm",
      @class
    ]}>
      <.icon name="hero-exclamation-triangle" class="shrink-0 text-orange-500" />
      <div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Visual information pane with left-side icon and arbitrary contents
  """
  attr :class, :string, default: nil, doc: "additional classes to apply"
  slot :inner_block, required: true

  def information(assigns) do
    ~H"""
    <div class={[
      "bg-purple-100 border border-purple-400 flex gap-3 items-center justify-start px-4 py-2 rounded text-sm",
      @class
    ]}>
      <.icon name="hero-information-circle" class="shrink-0 text-purple-500" />
      <div class="grow">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Visual information pane with left-side check mark and arbitrary contents
  """
  attr :class, :string, default: nil, doc: "additional classes to apply"
  slot :inner_block, required: true

  def confirmation(assigns) do
    ~H"""
    <div class={[
      "bg-green-100 border border-green-400 flex gap-3 items-center justify-start px-4 py-2 rounded text-sm",
      @class
    ]}>
      <.icon name="hero-check-circle" class="shrink-0 text-green-500" />
      <div class="grow">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :trap, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      data-show={show_modal(@id)}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-slate-200/75 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={if(@trap, do: %JS{}, else: JS.exec("data-cancel", to: "##{@id}"))}
              phx-key="escape"
              phx-click-away={if(@trap, do: %JS{}, else: JS.exec("data-cancel", to: "##{@id}"))}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-6 shadow-lg ring-1 transition"
            >
              <div class="absolute top-4 right-6">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label="close"
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        Hang in there while we get back on track
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-10 space-y-8 bg-white">
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :style, :string, default: "primary"
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        button_class(@style),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @button_class "font-semibold leading-6 py-1 px-2 rounded transition-colors phx-submit-loading:opacity-75"
  @button_primary_class "bg-orange-500 text-white active:text-white/80 disabled:bg-orange-400 disabled:cursor-not-allowed hover:bg-orange-400"
  @button_secondary_class "bg-transparent border border-orange-500 text-orange-600 disabled:border-orange-400 disabled:cursor-not-allowed disabled:text-orange-400 hover:bg-orange-50"
  @button_tertiary_class "bg-transparent border border-transparent disabled:cursor-not-allowed disabled:text-neutral-800 hover:text-orange-600"

  defp button_class("secondary"), do: [@button_class, @button_secondary_class]
  defp button_class("tertiary"), do: [@button_class, @button_tertiary_class]
  defp button_class(_default), do: [@button_class, @button_primary_class]

  @doc """
  Renders a link that looks like a button

  ## Examples

      <.button navigate={~p"/"}>Back</.button>

  """
  attr :class, :string, default: nil
  attr :style, :string, default: "primary"
  attr :rest, :global, include: ~w(href navigate patch)

  slot :inner_block, required: true

  def link_button(assigns) do
    ~H"""
    <.link
      class={[
        "inline-block",
        button_class(@style),
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :explanation, :string, default: nil
  attr :info_modal, :string, default: nil, doc: "ID of a modal for additional information"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :wrapper, :string, default: nil, doc: "additional classes for the wrapping element"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={@wrapper} phx-feedback-for={@name}>
      <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign_new(assigns, :field_is_required, fn -> assigns.rest[:required] == true end)

    ~H"""
    <div class={@wrapper} phx-feedback-for={@name}>
      <.label :if={@label} for={@id}>
        <%= @label %>
        <span :if={@field_is_required} class="text-orange-500"> *</span>
        <button :if={@info_modal} form="" phx-click={show_modal(@info_modal)}>
          <.icon class="align-text-bottom h-4 text-gray-700 w-4" name="hero-information-circle" />
        </button>
      </.label>
      <div :if={@explanation} class="text-gray-700 text-sm"><%= @explanation %></div>
      <select
        id={@id}
        name={@name}
        class="block mt-2 w-full rounded-md border border-gray-300 bg-white shadow-sm disabled:bg-slate-100 focus:border-zinc-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns = assign_new(assigns, :field_is_required, fn -> assigns.rest[:required] == true end)

    ~H"""
    <div class={@wrapper} phx-feedback-for={@name}>
      <.label for={@id}>
        <%= @label %>
        <span :if={@field_is_required} class="text-orange-500"> *</span>
        <button :if={@info_modal} form="" phx-click={show_modal(@info_modal)}>
          <.icon class="align-text-bottom h-4 text-gray-700 w-4" name="hero-information-circle" />
        </button>
      </.label>
      <div :if={@explanation} class="text-gray-700 text-sm"><%= @explanation %></div>
      <textarea
        id={@id}
        name={@name}
        class={[
          "block mt-2 w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-orange-500 focus:border-orange-500"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns = assign_new(assigns, :field_is_required, fn -> assigns.rest[:required] == true end)

    ~H"""
    <div class={@wrapper} phx-feedback-for={@name}>
      <.label for={@id}>
        <%= @label %>
        <span :if={@field_is_required} class="text-orange-500"> *</span>
        <button :if={@info_modal} form="" phx-click={show_modal(@info_modal)}>
          <.icon class="align-text-bottom h-4 text-gray-700 w-4" name="hero-information-circle" />
        </button>
      </.label>
      <div :if={@explanation} class="text-gray-700 text-sm"><%= @explanation %></div>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "block mt-2 w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-orange-500 focus:border-orange-500"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>
        "<%= Phoenix.HTML.Form.normalize_value(@type, @value) %>" <%= msg %>
      </.error>
    </div>
    """
  end

  @doc """
  iOS-style toggle switch that can replace a checkbox
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :value, :any

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: `@form[:accept]`"

  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :class, :string, default: nil, doc: "additional classes for the input element"
  attr :errors, :list, default: [], doc: "error messages to display below the input"
  attr :explanation, :string, default: nil
  attr :info_modal, :string, default: nil, doc: "ID of a modal for additional information"
  attr :label, :string, default: nil
  attr :wrapper, :string, default: nil, doc: "additional classes for the wrapper element"

  attr :rest, :global, include: ~w(autocomplete disabled form readonly required)

  def switch(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> switch()
  end

  def switch(assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns.value)
      end)
      |> assign_new(:field_is_required, fn -> assigns.rest[:required] == true end)

    ~H"""
    <div class={["group", @wrapper]} phx-feedback-for={@name}>
      <label class="flex items-start gap-2 relative text-sm">
        <input type="hidden" name={@name} value="false" />
        <div class="relative">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={["absolute opacity-0 peer", @class]}
            {@rest}
          />
          <div class={switch_class_bg()} />
          <div class={switch_class_fg()} />
        </div>
        <div>
          <div class="font-semibold">
            <%= @label %>
            <span :if={@field_is_required} class="text-orange-500"> *</span>
            <button :if={@info_modal} form="" phx-click={show_modal(@info_modal)}>
              <.icon class="align-text-bottom h-4 text-gray-700 w-4" name="hero-information-circle" />
            </button>
          </div>
          <div :if={@explanation} class="mt-1 text-gray-700"><%= @explanation %></div>
          <.error :for={msg <- @errors}><%= msg %></.error>
        </div>
      </label>
    </div>
    """
  end

  @switch_class_bg """
  bg-slate-300 h-5 rounded-xl transition-colors w-8
  peer-checked:bg-orange-500
  peer-disabled:opacity-40
  peer-disabled:cursor-not-allowed
  """
  defp switch_class_bg, do: @switch_class_bg

  @switch_class_fg """
  absolute bg-white h-4 left-0.5 rounded-lg top-0.5 transition-all w-4
  peer-checked:left-3.5
  peer-disabled:opacity-40
  peer-disabled:cursor-not-allowed
  """
  defp switch_class_fg, do: @switch_class_fg

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="ml-4 mt-2 flex gap-2 text-sm leading-6 text-orange-600 phx-no-feedback:hidden">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none bg-orange-500" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a collapsible table
  """
  attr :class, :string, default: nil, doc: "additional classes for the table"

  slot :row do
    attr :class, :string, doc: "additional classes for the row contents"
    attr :title, :string, required: true, doc: "row header"
  end

  def table(assigns) do
    ~H"""
    <dl class={["grid grid-table gap-x-8", @class]}>
      <%= for row <- @row do %>
        <dt class={["col-start-1 col-end-2 font-semibold small-caps", Map.get(row, :class)]}>
          <%= row.title %>
        </dt>
        <dd class={[
          "col-start-1 col-end-2 mb-2 xs:col-start-2 xs:col-end-3 last:mb-0",
          Map.get(row, :class)
        ]}>
          <%= render_slot(row) %>
        </dd>
      <% end %>
    </dl>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end

  @doc """
  Expandable content with a title and toggle arrow
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false, doc: "whether to show the content by default"
  attr :title, :string, required: true
  slot :inner_block, required: true

  def reveal(assigns) do
    ~H"""
    <div>
      <div
        class="cursor-pointer flex gap-4 items-center"
        phx-click={
          JS.toggle_class("h-0 h-auto", to: "##{@id}-reveal-contents")
          |> JS.toggle_class("rotate-180", to: "##{@id}-reveal-icon")
        }
      >
        <h3 class="font-semibold grow"><%= @title %></h3>
        <.icon class="transition-transform" id={"#{@id}-reveal-icon"} name="hero-chevron-up" />
      </div>
      <div
        class={["-m-2 overflow-hidden p-2", if(@show, do: "h-auto", else: "h-0")]}
        id={"#{@id}-reveal-contents"}
      >
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(RMWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(RMWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc "Create a naive pluralization of the given word"
  @spec dumb_inflect(String.t(), list | integer) :: String.t()
  def dumb_inflect(word, []), do: "0 #{word}s"
  def dumb_inflect(word, [_]), do: "1 #{word}"
  def dumb_inflect(word, list) when is_list(list), do: "#{length(list)} #{word}s"

  def dumb_inflect(word, 0), do: "0 #{word}s"
  def dumb_inflect(word, 1), do: "1 #{word}"
  def dumb_inflect(word, count) when is_integer(count), do: "#{count} #{word}s"

  @doc "Create a naive pluralization of the given word with an -es pluralization"
  @spec dumb_inflect_es(String.t(), list | integer) :: String.t()
  def dumb_inflect_es(word, []), do: "0 #{word}es"
  def dumb_inflect_es(word, [_]), do: "1 #{word}"
  def dumb_inflect_es(word, list) when is_list(list), do: "#{length(list)} #{word}es"

  def dumb_inflect_es(word, 0), do: "0 #{word}es"
  def dumb_inflect_es(word, 1), do: "1 #{word}"
  def dumb_inflect_es(word, count) when is_integer(count), do: "#{count} #{word}es"

  @doc "Create a naive pluralization of the given word with is/are in front"
  @spec dumb_inflect_is(String.t(), list | integer) :: String.t()
  def dumb_inflect_is(word, []), do: "are 0 #{word}s"
  def dumb_inflect_is(word, [_]), do: "is 1 #{word}"
  def dumb_inflect_is(word, list) when is_list(list), do: "are #{length(list)} #{word}s"

  def dumb_inflect_is(word, 0), do: "are 0 #{word}s"
  def dumb_inflect_is(word, 1), do: "is 1 #{word}"
  def dumb_inflect_is(word, count) when is_integer(count), do: "are #{count} #{word}s"

  @doc """
  Create a human-readable representation of the given date

  ## Formats

    * `:date` returns only date information, ex. `14 March 2020`
    * `:full` returns date and time, ex. `14 March 2020 at 15:26 UTC`

  """
  @spec format_date(Date.t() | DateTime.t() | nil, atom) :: String.t()
  def format_date(datetime, format, timezone \\ nil)
  def format_date(nil, :date, _zone), do: "Unknown Date"
  def format_date(nil, :full, _zone), do: "Unknown Time"

  def format_date(%Date{} = date, _format, _zone) do
    Calendar.strftime(date, "%-d %B %Y")
  end

  def format_date(datetime, :date, timezone) do
    timezone = timezone || Process.get(:client_timezone, "Etc/UTC")

    datetime
    |> DateTime.shift_zone!(timezone)
    |> Calendar.strftime("%-d %B %Y")
  end

  def format_date(datetime, :full, timezone) do
    timezone = timezone || Process.get(:client_timezone, "Etc/UTC")

    datetime
    |> DateTime.shift_zone!(timezone)
    |> Calendar.strftime("%-d %B %Y at %0H:%0M %Z")
  end

  @doc """
  Create a human-readable representation of a date range
  """
  @spec format_range(Date.t(), Date.t()) :: String.t()
  def format_range(start, finish)

  def format_range(same, same), do: format_date(same, :date)

  def format_range(
        %Date{year: same_year, month: same_month} = start,
        %Date{year: same_year, month: same_month} = finish
      ) do
    Calendar.strftime(start, "%-d–#{Calendar.strftime(finish, "%-d")} %B %Y")
  end

  def format_range(
        %Date{year: same_year} = start,
        %Date{year: same_year} = finish
      ) do
    Calendar.strftime(start, "%-d %B – #{Calendar.strftime(finish, "%-d %B")} %Y")
  end

  def format_range(start, finish) do
    format_date(start, :date) <> " – " <> format_date(finish, :date)
  end
end
