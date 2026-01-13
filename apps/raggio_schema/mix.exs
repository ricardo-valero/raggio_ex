defmodule RaggioSchema.MixProject do
  use Mix.Project

  def project do
    [
      app: :raggio_schema,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Publishing configuration
      description: "Composable schema definition and validation library",
      package: package(),
      name: "Raggio.Schema",
      source_url: "https://github.com/your_org/raggio"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.0"},
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      maintainers: ["Raggio Contributors"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/your_org/raggio"},
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end
end
