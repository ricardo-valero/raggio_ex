defmodule Raggio.BigQuery.RetryTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.Retry

  describe "with_retry/2" do
    test "returns result immediately on success" do
      result = Retry.with_retry(fn -> {:ok, "success"} end)
      assert result == {:ok, "success"}
    end

    test "returns non-retryable errors immediately" do
      result = Retry.with_retry(fn -> {:error, :not_found} end)
      assert result == {:error, :not_found}
    end

    test "returns non-error values immediately" do
      result = Retry.with_retry(fn -> :connected end)
      assert result == :connected
    end

    test "retries on HTTP 429 error" do
      counter = :counters.new(1, [])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            count = :counters.get(counter, 1)

            if count < 2 do
              {:error, {:http_error, 429, "rate limited"}}
            else
              {:ok, "success after retry"}
            end
          end,
          base_delay_ms: 1,
          max_delay_ms: 10
        )

      assert result == {:ok, "success after retry"}
      assert :counters.get(counter, 1) == 2
    end

    test "retries on :rate_limit_exceeded error" do
      counter = :counters.new(1, [])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            count = :counters.get(counter, 1)

            if count < 2 do
              {:error, :rate_limit_exceeded}
            else
              {:ok, "success"}
            end
          end,
          base_delay_ms: 1,
          max_delay_ms: 10
        )

      assert result == {:ok, "success"}
    end

    test "gives up after max_retries" do
      counter = :counters.new(1, [])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, {:http_error, 429, "always rate limited"}}
          end,
          max_retries: 2,
          base_delay_ms: 1,
          max_delay_ms: 5
        )

      assert {:error, {:http_error, 429, _}} = result
      assert :counters.get(counter, 1) == 3
    end

    test "emits telemetry event on retry" do
      test_pid = self()
      handler_id = "retry-test-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:raggio, :bigquery, :retry],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:retry_event, metadata})
        end,
        nil
      )

      counter = :counters.new(1, [])

      Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          count = :counters.get(counter, 1)

          if count < 2 do
            {:error, {:http_error, 429, "rate limited"}}
          else
            {:ok, "success"}
          end
        end,
        base_delay_ms: 1,
        max_delay_ms: 5
      )

      assert_receive {:retry_event, %{attempt: 1, reason: :rate_limit_exceeded}}

      :telemetry.detach(handler_id)
    end
  end

  describe "calculate_delay/3" do
    test "returns delay within bounds" do
      delay = Retry.calculate_delay(0, 100, 10_000)
      assert delay >= 100
      assert delay <= 10_000
    end

    test "delay increases with attempt number" do
      delays =
        for attempt <- 0..3 do
          Retry.calculate_delay(attempt, 100, 100_000)
        end

      for i <- 0..2 do
        assert Enum.at(delays, i) <= Enum.at(delays, i + 1) * 2
      end
    end

    test "respects max_delay cap" do
      delay = Retry.calculate_delay(10, 1000, 5000)
      assert delay <= 5000
    end

    test "adds jitter to delay" do
      delays = for _ <- 1..10, do: Retry.calculate_delay(0, 100, 10_000)
      unique_delays = Enum.uniq(delays)
      assert length(unique_delays) > 1
    end
  end
end
