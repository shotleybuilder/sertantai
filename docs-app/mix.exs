defmodule SertantaiDocs.MixProject do
  use Mix.Project

  def project do
    [
      app: :sertantai_docs,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SertantaiDocs.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix Framework
      {:phoenix, "~> 1.7.21"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: :test},
      {:meck, "~> 0.9.2", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      
      # Ash Framework for data management
      {:ash, "~> 3.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      
      # Markdown processing
      {:mdex, "~> 0.7.5"},
      {:yaml_elixir, "~> 2.9"},
      
      # UI Components
      {:petal_components, "~> 3.0"},
      
      # Core dependencies
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:file_system, "~> 1.0", only: [:dev, :test]},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind sertantai_docs", "esbuild sertantai_docs"],
      "assets.deploy": [
        "tailwind sertantai_docs --minify",
        "esbuild sertantai_docs --minify",
        "phx.digest"
      ],
      test: ["test"],
      "test.watch": ["test --stale --listen-on-stdin"],
      ci: ["format --check-formatted", "deps.unlock --check-unused", "test"],
      release: ["deps.get --only prod", "assets.deploy", "release"]
    ]
  end
end
