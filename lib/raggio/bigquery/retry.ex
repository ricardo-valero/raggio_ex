defmodule Raggio.BigQuery.Retry do
  @moduledoc """
  Exponential backoff retry logic for BigQuery API rate limiting.

  Handles HTTP 429 (rate limit exceeded) errors with configurable
  exponential backoff and jitter.

  ## Configuration

  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:base_delay_ms` - Initial delay in milliseconds (default: 1000)
  - `:max_delay_ms` - Maximum delay cap in milliseconds (default: 30000)

  ## Usage

      Raggio.BigQuery.Retry.with_retry(fn ->
        make_api_call()
      end, max_retries: 5, base_delay_ms: 500)
  """

  alias Raggio.BigQuery.Telemetry

  @default_max_retries 3
  @default_base_delay_ms 1000
  @default_max_delay_ms 30_000

  @doc """
  Execute a function with automatic retry on rate limit errors.

  Retries on:
  - `{:error, {:http_error, 429, _}}`
  - `{:error, :rate_limit_exceeded}`

  ## Options

  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:base_delay_ms` - Initial delay in milliseconds (default: 1000)
  - `:max_delay_ms` - Maximum delay cap in milliseconds (default: 30000)

  ## Returns

  The result of the function, or the last error after retries exhausted.
  """
  @spec with_retry((-> result), keyword()) :: result when result: any()
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)

    do_retry(fun, 0, max_retries, base_delay, max_delay)
  end

  defp do_retry(fun, attempt, max_retries, base_delay, max_delay) do
    case fun.() do
      {:error, {:http_error, 429, _}} when attempt < max_retries ->
        retry_after_delay(fun, attempt, max_retries, base_delay, max_delay, :rate_limit_exceeded)

      {:error, :rate_limit_exceeded} when attempt < max_retries ->
        retry_after_delay(fun, attempt, max_retries, base_delay, max_delay, :rate_limit_exceeded)

      result ->
        result
    end
  end

  defp retry_after_delay(fun, attempt, max_retries, base_delay, max_delay, reason) do
    delay = calculate_delay(attempt, base_delay, max_delay)
    emit_retry_event(attempt + 1, delay, reason)
    Process.sleep(delay)
    do_retry(fun, attempt + 1, max_retries, base_delay, max_delay)
  end

  @doc """
  Calculate delay with exponential backoff and jitter.

  Formula: min(base_delay * 2^attempt + random_jitter, max_delay)
  """
  @spec calculate_delay(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  def calculate_delay(attempt, base_delay, max_delay) do
    exponential = base_delay * trunc(:math.pow(2, attempt))
    jitter = :rand.uniform(max(1, div(exponential, 2)))
    min(exponential + jitter, max_delay)
  end

  defp emit_retry_event(attempt, delay_ms, reason) do
    Telemetry.emit([:retry], %{}, %{
      attempt: attempt,
      delay_ms: delay_ms,
      reason: reason
    })
  end
end
