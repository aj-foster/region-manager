import Config

if System.get_env("PHX_SERVER") do
  config :rm, RMWeb.Endpoint, server: true
end

if config_env() == :prod do
  #
  # DB
  #

  cacerts =
    System.fetch_env!("DATABASE_CACERT")
    |> :public_key.pem_decode()
    |> Enum.map(fn {:Certificate, cert, :not_encrypted} -> cert end)

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :rm, RM.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    ssl: [
      verify: :verify_peer,
      cacerts: cacerts,
      server_name_indication: :disable
    ]

  #
  # Mailer
  #

  config :rm, RM.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.fetch_env!("SES_HOST"),
    username: System.fetch_env!("SES_USER"),
    password: System.fetch_env!("SES_PASS"),
    hostname: System.fetch_env!("PHX_HOST"),
    port: 465,
    ssl: true,
    sockopts: [
      verify: :verify_peer,
      cacertfile: CAStore.file_path(),
      depth: 3,
      server_name_indication: :disable,
      middlebox_comp_mode: false
    ],
    tls: :never,
    auth: :always,
    retries: 1

  #
  # Endpoint
  #

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :rm, RMWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :rm, RMWeb.SESController,
    username: System.get_env("SNS_USERNAME"),
    password: System.get_env("SNS_PASSWORD")

  #
  # External
  #

  config :rm, External.FTCEvents,
    key: System.get_env("FTC_EVENTS_API_KEY"),
    user: System.get_env("FTC_EVENTS_API_USER")

  config :rm, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  #
  # Dependencies
  #

  config :ex_aws,
    s3: %{
      access_key_id: System.get_env("SPACES_ACCESS_ID"),
      secret_access_key: System.get_env("SPACES_ACCESS_KEY"),
      scheme: "https://",
      host: %{"nyc3" => System.get_env("SPACES_HOST")},
      region: "nyc3"
    }

  config :waffle,
    asset_host: System.get_env("ASSET_HOST", host),
    bucket: System.get_env("STORAGE_BUCKET", "ftcregion"),
    storage: Waffle.Storage.S3
end

if File.exists?(Path.expand("runtime.secret.exs", __DIR__)) do
  Code.require_file("runtime.secret.exs", __DIR__)
end
