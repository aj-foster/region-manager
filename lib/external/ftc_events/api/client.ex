defmodule External.FTCEvents.API.Client do
  @moduledoc """
  Default client for interacting with the FTC Events API

  In development and testing environments, this client may be replaced with a mock implementation
  instead.
  """
  @behaviour External.FTCEvents.API

  #
  # Callbacks
  #

  @impl true
  def list_leagues(season, opts \\ []) do
    req_opts = Keyword.take(opts, [:headers, :body, :params])
    url = "/v2.0/#{season}/leagues"

    params =
      Keyword.take(opts, [:league, :region])
      |> Map.new(fn
        {:league, league} -> {"leagueCode", league}
        {:region, region} -> {"regionCode", region}
      end)

    new(req_opts)
    |> Req.get(params: params, url: url)
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"leagueCount" => count, "leagues" => leagues}}} ->
        {:ok, %{count: count, leagues: leagues}}

      {:error, error} ->
        {:error, error}
    end
  end

  #
  # Request
  #

  @spec new(keyword) :: Req.Request.t()
  defp new(opts) do
    options =
      Keyword.merge(
        [
          auth: auth(),
          base_url: "https://ftc-api.firstinspires.org/",
          headers: [user_agent: user_agent()]
        ],
        opts
      )

    Req.new(options)
  end

  @spec auth :: {:basic, String.t()}
  defp auth do
    username = Application.get_env(:rm, External.FTCEvents, []) |> Keyword.fetch!(:user)
    key = Application.get_env(:rm, External.FTCEvents, []) |> Keyword.fetch!(:key)

    {:basic, "#{username}:#{key}"}
  end

  @spec user_agent :: String.t()
  defp user_agent do
    IO.iodata_to_binary([
      "Region Manager via Req ",
      Application.spec(:req, :vsn),
      "; Elixir ",
      System.version(),
      " / OTP ",
      System.otp_release()
    ])
  end
end
