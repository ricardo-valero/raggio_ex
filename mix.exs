defmodule Raggio.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/your-org/raggio"

  def project do
    [
      app: :raggio,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex package metadata
      description:
        "Composable data schema definition, validation, and syntax manipulation for Elixir",
      package: package(),

      # Docs
      name: "Raggio",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:decimal, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.0"},

      # Dev/Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: [:dev, :test]},

      # Example parser implementations (dev only - not bundled in production)
      {:nimble_csv, "~> 1.2", only: [:dev, :test]},
      {:xlsx_reader, "~> 0.8", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      main: "Raggio",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      maintainers: ["Ricardo Valero"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
