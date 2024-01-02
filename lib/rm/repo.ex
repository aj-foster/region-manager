defmodule RM.Repo do
  @moduledoc """
  Database interface

  Besides the callbacks defined by `Ecto.Repo`, this module provides helpers for automatically
  migrating the database on startup.
  """
  use Ecto.Repo,
    otp_app: :rm,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Migrate up to the latest version of the schema

  This function optionally accepts a version string (ex. `"20230712030805"`). The migrator will
  run all migrations up to and including the given version. If no version is supplied, all
  migrations will be run.
  """
  def migrate_up(version \\ nil) do
    Application.load(:rm)

    options =
      if version do
        [to: version]
      else
        [all: true]
      end

    {:ok, _, _} = Ecto.Migrator.with_repo(__MODULE__, &Ecto.Migrator.run(&1, :up, options))
  end

  @doc """
  Roll back to the given version of the schema (or one step)

  This function optionally accepts a version string (ex. `"20230712030805"`). The migrator will
  run all migrations **not including** the given version. If no version is supplied, a single step
  is rolled back.
  """
  def migrate_down(version \\ nil) do
    Application.load(:rm)

    options =
      if version do
        [to_exclusive: version]
      else
        [step: 1]
      end

    {:ok, _, _} = Ecto.Migrator.with_repo(__MODULE__, &Ecto.Migrator.run(&1, :down, options))
  end
end
