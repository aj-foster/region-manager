defmodule RM.Util.Captcha do
  require Logger
  use Phoenix.Component

  def component(assigns) do
    if enabled?() do
      ~H"""
      <div class="h-captcha" data-sitekey={site_key()}></div>
      <script src={script_url()} async defer>
      </script>
      """
    else
      ~H"""
      <div class="hidden h-captcha-disabled"></div>
      """
    end
  end

  @spec verify(map) :: :ok | :error
  def verify(params) do
    if enabled?() do
      params
      |> Map.put_new("h-captcha-response", nil)
      |> do_verify()
    else
      :ok
    end
  end

  @spec do_verify(map) :: :ok | :error
  defp do_verify(%{"h-captcha-response" => ""}), do: :error
  defp do_verify(%{"h-captcha-response" => nil}), do: :error

  defp do_verify(%{"h-captcha-response" => captcha_response} = params) do
    form = [
      secret: secret_key(),
      response: captcha_response,
      remoteip: params["remote_ip"]
    ]

    case Req.post(verify_url(), form: form) do
      {:ok, %Req.Response{status: 200, body: %{"success" => true}}} ->
        :ok

      {:ok, %Req.Response{status: 200, body: %{"success" => false, "error-codes" => codes}}} ->
        Logger.info("Captcha verification failed: #{inspect(codes)}")
        :error

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.info("Captcha verification unexpected response (#{status}): #{inspect(body)}")
        :error

      {:error, reason} ->
        Logger.info("Captcha verification request failed: #{inspect(reason)}")
        :error
    end
  end

  #
  # Config
  #

  @spec enabled? :: boolean
  defp enabled? do
    Application.fetch_env!(:rm, __MODULE__) |> Keyword.fetch!(:enabled)
  end

  @spec secret_key :: String.t()
  defp secret_key do
    Application.fetch_env!(:rm, __MODULE__) |> Keyword.fetch!(:secret_key)
  end

  @spec site_key :: String.t()
  defp site_key do
    Application.fetch_env!(:rm, __MODULE__) |> Keyword.fetch!(:site_key)
  end

  @default_script_url "https://js.hcaptcha.com/1/api.js"
  @default_verify_url "https://api.hcaptcha.com/siteverify"

  @spec script_url :: String.t()
  defp script_url do
    Application.fetch_env!(:rm, __MODULE__) |> Keyword.get(:script_url, @default_script_url)
  end

  @spec verify_url :: String.t()
  defp verify_url do
    Application.fetch_env!(:rm, __MODULE__) |> Keyword.get(:verify_url, @default_verify_url)
  end
end
