defmodule Raggio.MixProject do
  use Mix.Project

  @version "0.1.0"
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

      # Tabular parsing (Sheet Adapter feature)
      {:nimble_csv, "~> 1.2"},
      {:xlsx_reader, "~> 0.8"},

      # Dev/Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
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
