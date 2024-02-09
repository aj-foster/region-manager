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

config :waffle, storage: Waffle.Storage.Local

import_config "#{config_env()}.exs"
