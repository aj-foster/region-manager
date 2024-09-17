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
  def list_events(season, opts \\ []) do
    req_opts = Keyword.take(opts, [:headers, :body, :params])
    url = "/v2.0/#{season}/events"

    new(req_opts)
    |> Req.get(url: url)
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"eventCount" => count, "events" => events}}} ->
        {:ok, %{count: count, events: events}}

      {:ok, %Req.Response{status: code}} ->
        {:error, RuntimeError.exception("Received #{code} from FTC Events API")}

      {:error, error} ->
        {:error, error}
    end
  end

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

      {:ok, %Req.Response{status: code}} ->
        {:error, RuntimeError.exception("Received #{code} from FTC Events API")}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def list_league_members(season, region, league, opts \\ []) do
    req_opts = Keyword.take(opts, [:headers, :body, :params])
    url = "/v2.0/#{season}/leagues/members/#{region}/#{league}"

    new(req_opts)
    |> Req.get(url: url)
    |> case do
      {:ok, %Req.Response{status: 200, body: %{"members" => members}}} ->
        {:ok, members}

      {:ok, %Req.Response{status: code}} ->
        {:error, RuntimeError.exception("Received #{code} from FTC Events API")}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def list_teams(season, region, opts \\ []) do
    req_opts = Keyword.take(opts, [:headers, :body, :params])
    url = "/v2.0/#{season}/teams"

    params =
      Keyword.take(opts, [:page])
      |> Keyword.put(:state, region)

    new(req_opts)
    |> Req.get(params: params, url: url)
    |> case do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{
           "teams" => teams,
           "teamCountTotal" => team_count_total,
           "teamCountPage" => team_count_page,
           "pageCurrent" => page_current,
           "pageTotal" => page_total
         }
       }} ->
        {:ok,
         %{
           teams: teams,
           team_count_total: team_count_total,
           team_count_page: team_count_page,
           page_current: page_current,
           page_total: page_total
         }}

      {:ok, %Req.Response{status: code}} ->
        {:error, RuntimeError.exception("Received #{code} from FTC Events API")}

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
