defmodule RMWeb.SESController do
  @moduledoc """
  Webhook receiver for AWS SES email delivery notifications
  """
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  action_fallback :fallback

  def delivery(conn, params) do
    with :ok <- verify_message(params),
         :ok <- handle_management_messages(params) do
      send_resp(conn, :ok, "")
    end
  end

  #
  # Fallback
  #

  @doc false
  def fallback(conn, {:ignore, reason})
      when is_binary(reason),
      do: send_resp(conn, :ok, reason)

  def fallback(conn, {:error, code, reason})
      when is_atom(code) and is_binary(reason),
      do: send_resp(conn, code, reason)

  def fallback(conn, {:error, reason})
      when is_binary(reason),
      do: send_resp(conn, :internal_server_error, reason)

  #
  # Verify
  #

  require Record

  Record.defrecord(
    :otp_certificate,
    Record.extract(:OTPCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :otp_tbs_certificate,
    Record.extract(:OTPTBSCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecord(
    :otp_subject_public_key_info,
    Record.extract(:OTPSubjectPublicKeyInfo, from_lib: "public_key/include/public_key.hrl")
  )

  @spec verify_message(map) :: :ok | {:error, String.t()}
  def verify_message(message) do
    string_to_sign = construct_string_to_sign(message) <> "\n"

    with {:ok, key} <- get_public_key(message["SigningCertURL"]),
         {:ok, hash_algorithm} <- get_hash_algorithm(message["SignatureVersion"]),
         {:ok, decoded_signature} <- decode_signature(message["Signature"]) do
      if :public_key.verify(string_to_sign, hash_algorithm, decoded_signature, key) do
        :ok
      else
        {:error, "Signature verification failed"}
      end
    end
  end

  @spec construct_string_to_sign(map) :: String.t()
  def construct_string_to_sign(message)

  def construct_string_to_sign(%{"Type" => "Notification"} = message) do
    subject = Map.get(message, "Subject", "")

    [
      "Message",
      message["Message"],
      "MessageId",
      message["MessageId"],
      if(subject != "", do: "Subject"),
      if(subject != "", do: subject),
      "Timestamp",
      message["Timestamp"],
      "TopicArn",
      message["TopicArn"],
      "Type",
      message["Type"]
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  def construct_string_to_sign(message) do
    [
      "Message",
      message["Message"],
      "MessageId",
      message["MessageId"],
      "SubscribeURL",
      message["SubscribeURL"],
      "Timestamp",
      message["Timestamp"],
      "Token",
      message["Token"],
      "TopicArn",
      message["TopicArn"],
      "Type",
      message["Type"]
    ]
    |> Enum.join("\n")
  end

  @spec get_public_key(String.t()) :: {:ok, :public_key.public_key()} | {:error, String.t()}
  def get_public_key(signing_cert_url) do
    if key = :persistent_term.get({__MODULE__, signing_cert_url}, nil) do
      {:ok, key}
    else
      with :ok <- validate_signing_cert_url(signing_cert_url),
           {:ok, cert} <- download_signing_cert(signing_cert_url),
           {:ok, key} <- decode_signing_cert(cert) do
        :persistent_term.put({__MODULE__, signing_cert_url}, key)
        {:ok, key}
      end
    end
  end

  @spec validate_signing_cert_url(String.t()) :: :ok | {:error, String.t()}
  def validate_signing_cert_url(signing_cert_url) do
    valid_hostname? =
      URI.parse(signing_cert_url).host
      |> String.ends_with?("amazonaws.com")

    if valid_hostname? do
      :ok
    else
      {:error, "Invalid signing certificate URL"}
    end
  end

  @spec download_signing_cert(String.t()) :: {:ok, binary} | {:error, String.t()}
  def download_signing_cert(signing_cert_url) do
    case Req.get(signing_cert_url) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} when status in 400..599 ->
        {:error, "Failed to fetch signing certificate: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch signing certificate: #{inspect(reason)}"}
    end
  end

  @spec decode_signing_cert(binary) :: {:ok, :public_key.public_key()} | {:error, String.t()}
  def decode_signing_cert(cert) do
    :public_key.pem_decode(cert)
    |> then(&:lists.keysearch(:Certificate, 1, &1))
    |> then(fn {:value, {:Certificate, cert, :not_encrypted}} -> cert end)
    |> :public_key.pkix_decode_cert(:otp)
    |> otp_certificate(:tbsCertificate)
    |> otp_tbs_certificate(:subjectPublicKeyInfo)
    |> otp_subject_public_key_info(:subjectPublicKey)
    |> then(&{:ok, &1})
  rescue
    _ ->
      {:error, "Failed to decode signing certificate"}
  end

  @spec get_hash_algorithm(integer) :: {:ok, :sha | :sha256} | {:error, String.t()}
  def get_hash_algorithm("1"), do: {:ok, :sha}
  def get_hash_algorithm("2"), do: {:ok, :sha256}
  def get_hash_algorithm(_), do: {:error, "Unsupported signature version"}

  @spec decode_signature(String.t()) :: {:ok, binary} | {:error, String.t()}
  def decode_signature(signature) do
    case Base.decode64(signature) do
      {:ok, decoded_signature} -> {:ok, decoded_signature}
      :error -> {:error, "Invalid signature format"}
    end
  end

  #
  # Confirm Subscription
  #

  @spec handle_management_messages(map) ::
          :ok | {:ignore, String.t()} | {:error, atom, String.t()}
  def handle_management_messages(%{"Type" => "SubscriptionConfirmation"} = message) do
    case Req.get(message["SubscribeURL"]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ignore, "Subscription confirmation; not a notification"}

      {:ok, %Req.Response{status: status}} when status in 400..599 ->
        {:error, :bad_request, "Failed to confirm subscription: HTTP #{status}"}

      {:error, reason} ->
        {:error, :internal_server_error, "Failed to confirm subscription: #{inspect(reason)}"}
    end
  end

  def handle_management_messages(%{"Type" => "UnsubscribeConfirmation"}) do
    {:ignore, "Unsubscribe confirmation; not a notification"}
  end

  def handle_management_messages(_params), do: :ok
end
