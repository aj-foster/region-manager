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
