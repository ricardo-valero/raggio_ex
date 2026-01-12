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
        # Execute example file
        {output, exit_code} =
          System.cmd("elixir", [unquote(example_file)],
            stderr_to_stdout: true,
            env: [{"MIX_ENV", "test"}],
            cd: Path.expand("..", __DIR__)
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
