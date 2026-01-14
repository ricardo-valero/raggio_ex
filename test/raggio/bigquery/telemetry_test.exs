defmodule Raggio.BigQuery.TelemetryTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Telemetry

  setup do
    test_pid = self()

    handler_id = "test-handler-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:raggio, :bigquery, :test, :start],
        [:raggio, :bigquery, :test, :stop],
        [:raggio, :bigquery, :test, :exception],
        [:raggio, :bigquery, :custom]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  describe "span/3" do
    test "emits start and stop events for successful function" do
      result = Telemetry.span([:test], %{key: "value"}, fn -> :success end)

      assert result == :success

      assert_receive {:telemetry_event, [:raggio, :bigquery, :test, :start], start_measurements,
                      %{key: "value"}}

      assert Map.has_key?(start_measurements, :system_time)

      assert_receive {:telemetry_event, [:raggio, :bigquery, :test, :stop], stop_measurements, _}
      assert Map.has_key?(stop_measurements, :duration)
    end

    test "emits start and exception events when function raises" do
      assert_raise RuntimeError, "boom", fn ->
        Telemetry.span([:test], %{operation: "failing"}, fn ->
          raise "boom"
        end)
      end

      assert_receive {:telemetry_event, [:raggio, :bigquery, :test, :start], _,
                      %{operation: "failing"}}

      assert_receive {:telemetry_event, [:raggio, :bigquery, :test, :exception], measurements,
                      metadata}

      assert Map.has_key?(measurements, :duration)
      assert metadata[:kind] == :error
      assert %RuntimeError{} = metadata[:reason]
    end

    test "returns the function result" do
      result = Telemetry.span([:test], %{}, fn -> {:ok, 42} end)
      assert result == {:ok, 42}
    end

    test "passes metadata through to events" do
      Telemetry.span([:test], %{method: :get, url: "http://example.com"}, fn -> :ok end)

      assert_receive {:telemetry_event, [:raggio, :bigquery, :test, :start], _,
                      %{method: :get, url: "http://example.com"}}
    end
  end

  describe "emit/3" do
    test "emits a telemetry event with measurements and metadata" do
      Telemetry.emit([:custom], %{count: 5}, %{source: "test"})

      assert_receive {:telemetry_event, [:raggio, :bigquery, :custom], %{count: 5},
                      %{source: "test"}}
    end

    test "works with default empty measurements and metadata" do
      Telemetry.emit([:custom])

      assert_receive {:telemetry_event, [:raggio, :bigquery, :custom], %{}, %{}}
    end
  end
end
