defmodule ExamplesTest do
  use ExUnit.Case

  @examples_dir Path.join([__DIR__, "..", "examples"])

  test "all schema examples compile and run" do
    schema_examples = Path.wildcard(Path.join([@examples_dir, "schema", "**", "*.exs"]))

    assert length(schema_examples) > 0, "No schema examples found"

    for example <- schema_examples do
      assert {_, 0} = System.cmd("mix", ["run", example], stderr_to_stdout: true),
             "Example failed: #{example}"
    end
  end
end
