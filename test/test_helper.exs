ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(RM.Repo, :manual)

RM.Config.set_transient("current_season", 2024)
