defmodule Connect.Repo do
  use Ecto.Repo,
    otp_app: :connect,
    adapter: Ecto.Adapters.Postgres
end
