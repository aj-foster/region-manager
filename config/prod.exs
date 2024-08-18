import Config

config :rm, RMWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

#
# Dependencies
#

config :identity, notifier: Identity.Notifier.Swoosh

config :logger, level: :info

config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: RM.Finch
