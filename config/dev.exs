import Config

config :rm, RM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "rm_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :rm, RMWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "rPuVzCq9gAndc1nrZG4klWHfyI9/hI8MXRIwF3Okjj+V+JTY0kwRmOuhV8KO+E7J",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :rm, RMWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/rm_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :rm, dev_routes: true

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :plug_init_mode, :runtime
config :phoenix, :stacktrace_depth, 20
config :phoenix_live_view, :debug_heex_annotations, true
config :swoosh, :api_client, false

#
# Keila
#

config :keila, Keila.Repo,
  username: "postgres",
  password: "postgres",
  database: "rm_keila_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :keila, Keila.Mailings.SenderAdapters,
  adapters: [],
  shared_adapters: [Keila.Mailings.SenderAdapters.Shared.Local]

config :keila, Keila.Mailer, adapter: Swoosh.Adapters.Local
config :keila, Keila.Accounts, credits_enabled: true
