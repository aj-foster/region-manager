defmodule RMWeb.IdentityController do
  use RMWeb, :controller
  import Identity.Plug

  alias Plug.Conn
  alias RM.Account
  alias RM.Email

  plug :redirect_if_authenticated when action in [:new_user, :create_user]

  @spec new_user(Conn.t(), any) :: Conn.t()
  def new_user(conn, _params) do
    changeset = Account.User.create_changeset()
    render(conn, "new_user.html", changeset: changeset)
  end

  @spec create_user(Conn.t(), Conn.params()) :: Conn.t()
  def create_user(conn, %{"user" => user_params}) do
    if Email.known_email?(user_params["email"]) do
      token_url = fn token -> Identity.Phoenix.Util.url_for(conn, :confirm_email, token) end

      case Account.create_user(user_params, token_url: token_url) do
        {:ok, user} ->
          conn
          |> put_flash(:info, "A link to confirm your email has been sent to your address.")
          |> Identity.Plug.log_in_and_redirect_user(user, to: ~p"/register/post")

        {:error, changeset} ->
          render(conn, "new_user.html", changeset: changeset)
      end
    else
      redirect(conn, to: ~p"/register/error")
    end
  end

  @spec after_create_user(Conn.t(), Conn.params()) :: Conn.t()
  def after_create_user(conn, _params) do
    render(conn, "after_create_user.html")
  end

  @spec deny_create_user(Conn.t(), Conn.params()) :: Conn.t()
  def deny_create_user(conn, _params) do
    render(conn, "deny_create_user.html")
  end

  @spec confirm_email(Conn.t(), Conn.params()) :: Conn.t()
  def confirm_email(conn, %{"token" => token}) do
    case Account.confirm_email(token) do
      {:ok, _email} ->
        conn
        |> put_flash(:info, "Email address confirmed")
        |> redirect(to: ~p"/user/settings")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Email confirmation link is invalid or it has expired")
        |> redirect(to: ~p"/user/settings")
    end
  end
end
