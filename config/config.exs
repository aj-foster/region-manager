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

config :rm, RM.Mailer, adapter: Swoosh.Adapters.Local

config :rm, External.FTCEvents.API, client: External.FTCEvents.API.Client

#
# Dependencies
#

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :identity, notifier: Identity.Notifier.Swoosh, repo: RM.Repo, user: RM.Account.User
config :identity, Identity.Notifier.Swoosh, from: "noreply@ftcregion.com", mailer: RM.Mailer

config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :ex_aws, json_codec: Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :rm, Oban,
  engine: Oban.Engines.Basic,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"30 4 * * *", RM.FIRST.RefreshJob}
     ],
     timezone: "America/New_York"},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)},
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ],
  queues: [default: 10],
  repo: RM.Repo

config :tailwind,
  version: "3.3.2",
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

import_config "#{config_env()}.exs"
