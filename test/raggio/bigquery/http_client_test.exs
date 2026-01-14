defmodule Raggio.BigQuery.HTTPClientTest do
  use ExUnit.Case, async: true

  alias Raggio.BigQuery.{HTTPClient, MockHTTPClient}

  describe "behaviour compliance" do
    test "MockHTTPClient implements HTTPClient behaviour" do
      behaviours = MockHTTPClient.__info__(:attributes)[:behaviour] || []
      assert HTTPClient in behaviours
    end

    test "MockHTTPClient.request/5 returns expected response shape" do
      url = "https://bigquery.googleapis.com/bigquery/v2/projects/test/datasets/test"
      {:ok, response} = MockHTTPClient.request(:get, url, [], nil, [])

      assert is_map(response)
      assert Map.has_key?(response, :status)
      assert Map.has_key?(response, :headers)
      assert Map.has_key?(response, :body)
      assert is_integer(response.status)
      assert is_list(response.headers)
      assert is_binary(response.body)
    end
  end

  describe "MockHTTPClient responses" do
    test "returns 200 for dataset GET request" do
      url = "https://bigquery.googleapis.com/bigquery/v2/projects/test/datasets/my_dataset"
      {:ok, response} = MockHTTPClient.request(:get, url, [], nil, [])

      assert response.status == 200
      assert String.contains?(response.body, "bigquery#dataset")
    end

    test "returns 200 for table GET request" do
      url = "https://bigquery.googleapis.com/bigquery/v2/projects/test/datasets/ds/tables/tbl"
      {:ok, response} = MockHTTPClient.request(:get, url, [], nil, [])

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["kind"] == "bigquery#table"
      assert body["schema"]["fields"]
    end

    test "returns 200 for insertAll request" do
      url =
        "https://bigquery.googleapis.com/bigquery/v2/projects/test/datasets/ds/tables/tbl/insertAll"

      {:ok, response} = MockHTTPClient.request(:post, url, [], "{}", [])

      assert response.status == 200
      assert String.contains?(response.body, "tableDataInsertAllResponse")
    end

    test "returns 200 for query request" do
      url = "https://bigquery.googleapis.com/bigquery/v2/projects/test/queries"
      {:ok, response} = MockHTTPClient.request(:post, url, [], "{}", [])

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["kind"] == "bigquery#queryResponse"
    end

    test "returns 200 for job request" do
      url = "https://bigquery.googleapis.com/bigquery/v2/projects/test/jobs"
      {:ok, response} = MockHTTPClient.request(:post, url, [], "{}", [])

      assert response.status == 200
      body = Jason.decode!(response.body)
      assert body["kind"] == "bigquery#job"
    end

    test "returns 404 for unknown endpoints" do
      url = "https://bigquery.googleapis.com/bigquery/v2/unknown"
      {:ok, response} = MockHTTPClient.request(:get, url, [], nil, [])

      assert response.status == 404
    end
  end
end
