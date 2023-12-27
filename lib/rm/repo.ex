defmodule RM.Repo do
  use Ecto.Repo,
    otp_app: :rm,
    adapter: Ecto.Adapters.Postgres
end
