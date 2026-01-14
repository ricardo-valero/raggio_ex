defmodule Raggio.BigQuery.Table do
  @moduledoc """
  Behaviour for BigQuery table definitions.

  Implement this behaviour to define a BigQuery table schema with metadata.
  Uses Raggio.Schema for type definitions.

  ## Example

      defmodule MyApp.Tables.Charges do
        use Raggio.BigQuery.Table
        alias Raggio.Schema

        @impl true
        def __dataset__, do: "billing"

        @impl true
        def __table__, do: "charges"

        @impl true
        def __schema__ do
          Schema.struct([
            {:id, Schema.string()},
            {:amount, Schema.decimal()},
            {:status, Schema.literal(:pending, :completed, :failed)},
            {:created_at, Schema.datetime()}
          ])
        end

        @impl true
        def __time_partitioning__, do: [field: :created_at, type: :day]

        @impl true
        def __clustering__, do: [:status]
      end
  """

  @callback __dataset__() :: String.t()
  @callback __table__() :: String.t()
  @callback __schema__() :: Raggio.Schema.Type.t()
  @callback __time_partitioning__() :: keyword() | nil
  @callback __clustering__() :: [atom()] | nil

  @optional_callbacks [__time_partitioning__: 0, __clustering__: 0]

  defmacro __using__(_opts) do
    quote do
      @behaviour Raggio.BigQuery.Table

      def __time_partitioning__, do: nil
      def __clustering__, do: nil
      def __qualified_name__, do: "#{__dataset__()}.#{__table__()}"

      defoverridable __time_partitioning__: 0, __clustering__: 0
    end
  end
end
