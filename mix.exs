defmodule RM.MixProject do
  use Mix.Project

  def project do
    [
      app: :rm,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [rm: [steps: [:assemble, :tar]]],
      listeners: listeners(),
      dialyzer: [
        plt_add_apps: [:keila]
      ]
    ]
  end

  def application do
    [
      mod: {RM.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:bandit, ">= 0.0.0"},
      {:castore, "~> 1.0"},
      {:dns_cluster, "~> 0.2.0"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ecto_sql, "~> 3.10"},
      {:elixlsx, "~> 0.6.0"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:eqrcode, "~> 0.2.0"},
      {:ex_aws, "~> 2.7"},
      {:ex_aws_s3, "~> 2.5"},
      {:ex_machina, "~> 2.8", only: :test},
      # Required by Keila.
      {:fast_html, "~> 2.5"},
      {:finch, "~> 0.13"},
      # Normally only: :test, but keila requires it elsewhere.
      {:floki, ">= 0.30.0"},
      {:gen_smtp, "~> 1.0"},
      {:hackney, "~> 4.0", override: true},
      {:identity, github: "aj-foster/identity", branch: "main"},
      {:jason, "~> 1.2"},
      {:keila, github: "pentacent/keila", ref: "v0.20.0", runtime: false},
      {:nimble_csv, "~> 1.3.0"},
      {:nimble_totp, "~> 1.0"},
      {:oban, "~> 2.17"},
      # keila wants 1.7
      {:phoenix, "~> 1.8.0", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.6"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.6.2"},
      {:sweet_xml, "~> 0.7.4"},
      {:swoosh, "~> 1.3"},
      {:tailwind, "~> 0.5.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tz, "~> 0.28"},
      {:tz_extra, "~> 0.45.0"},
      {:ua_parser, github: "beam-community/ua_parser", override: true},
      {:waffle, "~> 1.1"},
      {:waffle_ecto, "~> 0.0.12"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp listeners do
    if dependabot?(), do: [], else: [Phoenix.CodeReloader]
  end

  defp dependabot? do
    Enum.any?(System.get_env(), fn {key, _value} -> String.starts_with?(key, "DEPENDABOT") end)
  end
end
