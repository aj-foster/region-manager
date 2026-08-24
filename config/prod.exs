import Config

config :rm, RMWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

#
# Dependencies
#

config :appsignal, :config,
  # Capture revision as a short Git SHA at compile time
  revision: System.get_env("APP_REVISION"),

  # Sheer throughput from region websites would use all of AppSignal's requests
  ignore_actions: [
    "RMWeb.RegionController#events",
    "RMWeb.RegionController#teams",
    "RMWeb.RegionController#videos"
  ]

config :logger, level: :info

config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: RM.Finch
