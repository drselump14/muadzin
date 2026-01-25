defmodule Muadzin.MixProject do
  use Mix.Project

  @app :muadzin
  @version "0.1.0"
  @all_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4, :bbb, :osd32mp1, :x86_64, :grisp2]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      archives: [nerves_bootstrap: "~> 1.11"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host],
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Muadzin.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.3"},
      {:toolshed, "~> 0.4.2"},
      {:typed_struct, "~> 0.3.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:azan_ex, "~> 0.3.0"},
      {:domo, "~> 1.5.19", override: true},
      {:tzdata, "~> 1.1"},

      # Phoenix dependencies
      {:phoenix, "~> 1.7.14"},
      {:phoenix_live_view, "~> 0.20.17"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:bun, "~> 1.3", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:cors_plug, "~> 3.0"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.13.0", targets: @all_targets},
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},
      {:logger_papertrail_backend, "~> 1.0"},

      # Dependencies for specific targets
      # NOTE: It's generally low risk and recommended to follow minor version
      # bumps to Nerves systems. Since these include Linux kernel and Erlang
      # version updates, please review their release notes in case
      # changes to your application are needed.
      {:nerves_system_rpi, "~> 1.33", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.33", runtime: false, targets: :rpi0},
      {:nerves_system_rpi2, "~> 1.33", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 1.33", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.33", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.33", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5, "~> 0.2", runtime: false, targets: :rpi4},
      {:nerves_system_bbb, "~> 2.29", runtime: false, targets: :bbb},
      {:nerves_system_osd32mp1, "~> 0.24", runtime: false, targets: :osd32mp1},
      {:nerves_system_x86_64, "~> 1.33", runtime: false, targets: :x86_64},
      {:nerves_system_grisp2, "~> 0.17", runtime: false, targets: :grisp2},
      {:nerves_system_mangopi_mq_pro, "~> 0.6", runtime: false, targets: :mangopi_mq_pro}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "bun.install --if-missing"],
      "assets.build": ["tailwind default", "bun default"],
      "assets.deploy": ["tailwind default --minify", "bun default", "phx.digest"]
    ]
  end
end
