defmodule RMWeb.EmailController do
  use RMWeb, :controller
  require Logger

  alias RM.Email
  alias RM.FIRST

  @doc """
  GET + POST /email/sub/:region
  """
  def subscribe(conn, params) do
    conn = assign(conn, success: nil, error: nil)
    params = Map.put(params, "remote_ip", conn.remote_ip |> :inet.ntoa() |> to_string())

    with {:ok, conn} <- load_region_and_leagues(conn, params),
         :ok <- verify_post_captcha(conn, params),
         :ok <- verify_params(conn, params),
         {:ok, conn} <- maybe_subscribe_region(conn, params),
         {:ok, conn} <- maybe_subscribe_leagues(conn, params) do
      render(conn, "subscribe.html")
    end
  end

  defp load_region_and_leagues(conn, %{"region" => region_code} = params) do
    case FIRST.fetch_region_by_abbreviation(region_code) do
      {:ok, region} ->
        region = RM.Repo.preload(region, leagues: :settings)

        leagues =
          region.leagues
          |> Enum.filter(&(&1.settings && &1.settings.enable_email))
          |> Enum.sort_by(& &1.name)
          |> Enum.map(&%{&1 | region: region})

        submitted_params =
          params
          |> Map.get("subscribe", %{})
          |> Map.take(["email", "name", "region", "leagues"])

        form_params =
          Map.merge(
            %{"email" => "", "name" => "", "region" => false, "leagues" => %{}},
            submitted_params
          )

        form = Phoenix.Component.to_form(form_params, as: :subscribe)

        {:ok, assign(conn, region: region, leagues: leagues, form: form)}

      {:error, :region, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(RMWeb.ErrorView, "404.html")
    end
  end

  defp verify_post_captcha(%{method: "POST"} = conn, params) do
    case RM.Util.Captcha.verify(params) do
      :ok ->
        :ok

      :error ->
        conn
        |> assign(error: "Captcha verification failed. Please try again.")
        |> render("subscribe.html")
    end
  end

  defp verify_post_captcha(_conn, _params), do: :ok

  defp verify_params(conn, %{"subscribe" => %{"email" => <<email::binary>>}}) do
    cond do
      email == "" ->
        conn
        |> assign(error: "Email address is required.")
        |> render("subscribe.html")

      not Regex.match?(~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, email) ->
        conn
        |> assign(error: "Invalid email address format.")
        |> render("subscribe.html")

      :else ->
        :ok
    end
  end

  defp verify_params(_conn, _params), do: :ok

  defp maybe_subscribe_region(
         %{assigns: %{region: region}, method: "POST"} = conn,
         %{"subscribe" => %{"region" => "true"} = params}
       ) do
    case Email.subscribe_email(params["email"], params["name"], region) do
      {:ok, _} ->
        {:ok, assign(conn, success: "You have successfully subscribed to email updates.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning(
          "Failed to subscribe email for region #{region.code}: #{inspect(changeset)}"
        )

        conn
        |> assign(error: "There was an error subscribing your email address.")
        |> render("subscribe.html")
    end
  end

  defp maybe_subscribe_region(conn, _params), do: {:ok, conn}

  defp maybe_subscribe_leagues(
         %{assigns: %{leagues: leagues}, method: "POST"} = conn,
         %{"subscribe" => %{"leagues" => league_params} = params}
       ) do
    Enum.reduce_while(leagues, {:ok, conn}, fn league, {:ok, conn} ->
      if league_params[league.code] == "true" do
        case Email.subscribe_email(params["email"], params["name"], league) do
          {:ok, _} ->
            {:cont,
             {:ok, assign(conn, success: "You have successfully subscribed to email updates.")}}

          {:error, %Ecto.Changeset{} = changeset} ->
            Logger.warning(
              "Failed to subscribe email for league #{league.code}: #{inspect(changeset)}"
            )

            conn =
              conn
              |> assign(error: "There was an error subscribing your email address.")
              |> render("subscribe.html")

            {:halt, conn}
        end
      else
        {:cont, {:ok, conn}}
      end
    end)
  end

  defp maybe_subscribe_leagues(conn, _params), do: {:ok, conn}

  @doc """
  POST /email/unsub/:project/:message/:token

  Automated unsubscribe endpoint for email messages sent via Keila. This endpoint is used by the
  unsubscribe link in the email headers. The related GET endpoint is a LiveView with additional
  subscription management features.
  """
  def unsubscribe(conn, %{"project" => project_id, "message" => message_id, "token" => token}) do
    conn = assign(conn, success: false, error: nil)

    with {:ok, project} <- Email.fetch_keila_project(project_id),
         {:ok, message} <- Email.fetch_keila_message(message_id),
         {:ok, contact} <- Email.fetch_keila_contact(message.contact_id),
         :ok <- Email.validate_unsubscribe_token(project, message, token),
         {:ok, _address} <- Email.mark_email_undeliverable(contact.email, :unsubscribe) do
      conn
      |> assign(success: true)
      |> render("unsubscribe.html")
    else
      {:error, %Ecto.Changeset{}} ->
        conn
        |> assign(:error, "There was an error unsubscribing your email address.")
        |> render("unsubscribe.html")

      {:error, _reason} ->
        conn
        |> assign(:error, "The unsubscribe link is invalid or has expired.")
        |> render("unsubscribe.html")
    end
  end
end
