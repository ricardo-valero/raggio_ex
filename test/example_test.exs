defmodule ExampleTest do
  use ExUnit.Case, async: true

  @examples_dir Path.expand("../examples", __DIR__)

  @example_files @examples_dir
                 |> Path.join("**/*.exs")
                 |> Path.wildcard()
                 |> Enum.filter(fn path ->
                   String.contains?(path, "/schema/basic_validation/") or
                     String.contains?(path, "/schema/adapters/") or
                     String.contains?(path, "/syntax/node_building/") or
                     String.contains?(path, "/syntax/tree_traversal/")
                 end)
                 |> Enum.sort()

  describe "example verification" do
    for example_file <- @example_files do
      relative_path = Path.relative_to(example_file, @examples_dir)

      @tag example_file: example_file
      @tag relative_path: relative_path
      test "example: #{relative_path}" do
        project_root = Path.expand("..", __DIR__)
        raggio_ebin = Path.join([project_root, "_build", "test", "lib", "raggio", "ebin"])
        decimal_ebin = Path.join([project_root, "_build", "test", "lib", "decimal", "ebin"])
        jason_ebin = Path.join([project_root, "_build", "test", "lib", "jason", "ebin"])

        {output, exit_code} =
          System.cmd(
            "elixir",
            ["-pa", raggio_ebin, "-pa", decimal_ebin, "-pa", jason_ebin, unquote(example_file)],
            stderr_to_stdout: true,
            env: [{"MIX_ENV", "test"}],
            cd: project_root
          )

        assert exit_code == 0, """
        Example failed: #{unquote(relative_path)}
        Output:
        #{output}
        """

        assert String.length(output) > 0, "Example produced no output"
      end
    end
  end
end
