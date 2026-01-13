defmodule ExampleTest do
  use ExUnit.Case, async: true

  @examples_dir Path.expand("../examples", __DIR__)

  # Discover all .exs files in examples directory
  @example_files @examples_dir
                 |> Path.join("**/*.exs")
                 |> Path.wildcard()
                 |> Enum.sort()

  describe "example verification" do
    for example_file <- @example_files do
      relative_path = Path.relative_to(example_file, @examples_dir)

      @tag example_file: example_file
      @tag relative_path: relative_path
      test "example: #{relative_path}" do
        # Execute example file with compiled module paths
        project_root = Path.expand("..", __DIR__)
        schema_ebin = Path.join([project_root, "_build", "test", "lib", "raggio_schema", "ebin"])
        syntax_ebin = Path.join([project_root, "_build", "test", "lib", "raggio_syntax", "ebin"])

        {output, exit_code} =
          System.cmd("elixir", ["-pa", schema_ebin, "-pa", syntax_ebin, unquote(example_file)],
            stderr_to_stdout: true,
            env: [{"MIX_ENV", "test"}],
            cd: project_root
          )

        # Verify execution succeeded
        assert exit_code == 0, """
        Example failed: #{unquote(relative_path)}
        Output:
        #{output}
        """

        # Verify output is not empty (example should produce some output)
        assert String.length(output) > 0, "Example produced no output"
      end
    end
  end
end
