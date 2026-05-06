import Config

#
# RM
#

config :rm,
  ecto_repos: [RM.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :rm, RMWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RMWeb.ErrorHTML, json: RMWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RM.PubSub,
  live_view: [signing_salt: "RApVjbt+"]

config :rm, RM.Mailer, adapter: Swoosh.Adapters.Local, hostname: "rm.local"

config :rm, External.FTCEvents.API, client: External.FTCEvents.API.Client

#
# Dependencies
#

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :ex_aws, json_codec: Jason

config :identity, notifier: RM.Mailer, repo: RM.Repo, user: RM.Account.User

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime, :types, %{"text/tab-separated-values" => ["tsv"]}

config :phoenix, :json_library, Jason

config :rm, Oban,
  engine: Oban.Engines.Basic,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"30 4 * * *", RM.FIRST.RefreshJob},
       {"* * * * *", Keila.Mailings.DeliverScheduledCampaignsWorker},
       {"* * * * *", Keila.Mailings.ScheduleWorker}
     ],
     timezone: "America/New_York"},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)},
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ],
  queues: [
    default: 10,
    # Keila
    mailer: 50,
    mailer_scheduler: 1
  ],
  repo: RM.Repo

config :tailwind,
  version: "3.4.15",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :waffle,
  asset_host: "http://localhost:4000/waffle",
  storage: Waffle.Storage.Local,
  storage_dir_prefix: "priv/static/waffle"

#
# Keila
#

config :keila, ecto_repos: [Keila.Repo]
config :keila, KeilaWeb.ContactsCsvExport, chunk_size: 100
config :keila, KeilaWeb.Endpoint, server: false
config :keila, Keila.Files, adapter: Keila.Files.StorageAdapters.Local
config :keila, Keila.Files.StorageAdapters.Local, serve: true, dir: "./uploads"

config :keila, Keila.Id,
  alphabet: "abcdefghijkmnopqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWXYZ",
  min_len: 8

config :keila, Keila.Mailings, min_campaign_schedule_offset: 300, enable_precedence_header: true

config :keila, Keila.Mailings.SenderAdapters,
  adapters: [],
  shared_adapters: [Keila.Mailings.SenderAdapters.Shared.SES]

config :keila, Keila.Accounts, credits_enabled: false

config :keila, KeilaWeb.Captcha,
  secret_key: "0x0000000000000000000000000000000000000000",
  site_key: "10000000-ffff-ffff-ffff-000000000001",
  url: "https://hcaptcha.com/siteverify",
  provider: :hcaptcha

config :keila, KeilaWeb.Gettext, default_locale: "en", locales: ["en"]
config :ex_cldr, default_backend: Keila.Cldr
config :keila, Keila.Auth.Emails, from_email: "keila@localhost"

import_config "#{config_env()}.exs"
