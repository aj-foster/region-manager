defmodule RM.Repo.Migrations.AddLogoToSeasons do
  use Ecto.Migration

  def change do
    alter table(:first_seasons) do
      add :logo_url, :text
    end

    execute "UPDATE first_seasons SET logo_url = 'https://assets.ftcregion.com/static/seasons/2023-logo.png' WHERE year = 2023",
            "SELECT 1"

    execute "UPDATE first_seasons SET logo_url = 'https://assets.ftcregion.com/static/seasons/2024-logo.png' WHERE year = 2024",
            "SELECT 1"
  end
end
