defmodule Raggio.BigQuery.MockHTTPClient do
  @moduledoc false
  @behaviour Raggio.BigQuery.HTTPClient

  @impl true
  def request(method, url, _headers, _body, _opts) do
    cond do
      String.contains?(url, "/tables/") and String.contains?(url, "/insertAll") ->
        {:ok,
         %{status: 200, headers: [], body: ~s({"kind": "bigquery#tableDataInsertAllResponse"})}}

      String.contains?(url, "/tables/") and method == :get ->
        {:ok,
         %{
           status: 200,
           headers: [],
           body:
             Jason.encode!(%{
               "kind" => "bigquery#table",
               "schema" => %{
                 "fields" => [
                   %{"name" => "id", "type" => "STRING", "mode" => "REQUIRED"},
                   %{"name" => "name", "type" => "STRING", "mode" => "NULLABLE"}
                 ]
               }
             })
         }}

      String.contains?(url, "/tables") and method == :post ->
        {:ok,
         %{
           status: 201,
           headers: [],
           body:
             Jason.encode!(%{
               "kind" => "bigquery#table",
               "schema" => %{"fields" => []}
             })
         }}

      String.contains?(url, "/queries") ->
        {:ok,
         %{
           status: 200,
           headers: [],
           body:
             Jason.encode!(%{
               "kind" => "bigquery#queryResponse",
               "schema" => %{"fields" => [%{"name" => "count", "type" => "INTEGER"}]},
               "rows" => [%{"f" => [%{"v" => "42"}]}]
             })
         }}

      String.contains?(url, "/jobs/") and method == :get ->
        {:ok,
         %{
           status: 200,
           headers: [],
           body:
             Jason.encode!(%{
               "kind" => "bigquery#job",
               "status" => %{"state" => "DONE"}
             })
         }}

      String.contains?(url, "/jobs") and method == :post ->
        {:ok,
         %{
           status: 200,
           headers: [],
           body:
             Jason.encode!(%{
               "kind" => "bigquery#job",
               "status" => %{"state" => "RUNNING"}
             })
         }}

      String.contains?(url, "/datasets/") and method == :get ->
        {:ok, %{status: 200, headers: [], body: ~s({"kind": "bigquery#dataset", "id": "test"})}}

      true ->
        {:ok,
         %{status: 404, headers: [], body: ~s({"error": {"code": 404, "message": "Not found"}})}}
    end
  end
end
