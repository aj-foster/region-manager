import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :rm, RM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rm_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rm, RMWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zTLoW/VtxDrXLm1T+1rkp3qot044jux5qbMiCexwTT81dMx+VxqP2k8y23q5f/PB",
  server: false

# In test we don't send emails.
config :rm, RM.Mailer, adapter: Swoosh.Adapters.Test

config :rm, External.FTCEvents.API, client: External.FTCEvents.API.Stub

config :rm, Oban, testing: :inline

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

#
# Keila
#

config :keila, Keila.Repo,
  url: "ecto://postgres:postgres@localhost:5432/rm_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 60_000,
  timeout: 60_000,
  pool_size: 16

config :keila, KeilaWeb.ContactsCsvExport, chunk_size: 3

# Configure Swoosh
config :keila, Keila.Mailer, adapter: Swoosh.Adapters.Test

# Configure Argon2 for performance (not security)
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure Oban for testing
config :keila, Oban, testing: :manual

# Allow scheduling campaigns at utc_now
config :keila, Keila.Mailings, min_campaign_schedule_offset: -10

# Only use test and smtp Sender Adapters
config :keila, Keila.Mailings.SenderAdapters,
  adapters: [
    Keila.Mailings.SenderAdapters.SMTP,
    Keila.Mailings.SenderAdapters.SES
    # Disabled due to Keila not including this module when compiling as a dependency.
    # Keila.TestSenderAdapter
  ]

# Disable sending quotas by default in testing
config :keila, Keila.Accounts, credits_enabled: false
