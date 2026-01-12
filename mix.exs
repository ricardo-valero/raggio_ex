defmodule Raggio.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_paths: ["test"]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end

  # Aliases for coordinated operations across packages
  defp aliases do
    [
      "test.all": ["test", "cmd --app raggio_schema mix test", "cmd --app raggio_syntax mix test"],
      "format.all": [
        "format",
        "cmd --app raggio_schema mix format",
        "cmd --app raggio_syntax mix format"
      ]
    ]
  end
end
