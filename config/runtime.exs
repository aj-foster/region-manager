import Config

if System.get_env("PHX_SERVER") do
  config :rm, RMWeb.Endpoint, server: true
end

if config_env() == :prod do
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
    ssl: true,
    ssl_opts: [
      verify: :verify_peer,
      cacerts: cacerts,
      server_name_indication: :disable
    ]

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :rm, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :rm, RMWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

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
