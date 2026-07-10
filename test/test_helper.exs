Ecto.Adapters.SQL.Sandbox.mode(RM.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Keila.Repo, :manual)
RM.System.Config.set_transient("current_season", 2024)

ExUnit.start()
