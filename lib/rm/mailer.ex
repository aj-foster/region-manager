defmodule RM.Mailer do
  use Swoosh.Mailer, otp_app: :rm
  @behaviour Identity.Notifier

  #
  # Identity.Notifier Callbacks
  #

  @impl Identity.Notifier
  def confirm_email(email, url) do
    base()
    |> Swoosh.Email.to([email])
    |> Swoosh.Email.subject("Welcome! Please confirm your email")
    |> render_body(:confirm_email,
      preview: "Welcome to Region Manager! Please confirm your email address.",
      title: "Welcome to Region Manager! Please confirm your email address.",
      url: url
    )
    |> deliver()
    |> case do
      {:ok, _email} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Identity.Notifier
  def reset_password(user, url) do
    emails = Identity.list_emails(user)

    base()
    |> Swoosh.Email.to(emails)
    |> Swoosh.Email.subject("Finish Resetting Your Password")
    |> render_body(:reset_password,
      preview: "Someone asked to reset your password. Here's the link to continue.",
      title: "Here's your password reset link",
      url: url
    )
    |> deliver()
    |> case do
      {:ok, _email} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  #
  # Helpers
  #

  @spec base :: Swoosh.Email.t()
  defp base do
    hostname = Application.get_env(:rm, RM.Mailer, [])[:hostname]
    Swoosh.Email.new(from: {"Region Manager", "no-reply@#{hostname}"})
  end

  @spec render_body(Swoosh.Email.t(), atom, keyword) :: Swoosh.Email.t()
  defp render_body(email, template, assigns) do
    html_heex = apply(RMWeb.Email, String.to_atom("#{template}_html"), [assigns])

    html =
      Keyword.put(assigns, :inner_content, html_heex)
      |> RMWeb.Email.email_html()

    text_heex = apply(RMWeb.Email, String.to_atom("#{template}_text"), [assigns])

    text =
      Keyword.put(assigns, :inner_content, text_heex)
      |> RMWeb.Email.email_text()

    email
    |> Swoosh.Email.html_body(render_heex(html))
    |> Swoosh.Email.text_body(render_heex(text))
  end

  @spec render_heex(term) :: String.t()
  defp render_heex(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
