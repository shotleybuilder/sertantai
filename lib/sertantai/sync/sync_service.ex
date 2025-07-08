defmodule Sertantai.Sync.SyncService do
  @moduledoc """
  Service for syncing records to external no-code databases.
  Supports Airtable, Notion, and Zapier integrations.
  """

  require Logger
  require Ash.Query
  import Ash.Expr
  alias Sertantai.Sync.{SyncConfiguration, SelectedRecord}

  @doc """
  Sync a configuration with its selected records to the external provider.
  """
  def sync_configuration(sync_config_id) do
    Logger.info("Starting sync for configuration: #{sync_config_id}")

    with {:ok, sync_config} <- load_sync_configuration(sync_config_id),
         {:ok, credentials} <- decrypt_credentials(sync_config),
         {:ok, selected_records} <- load_selected_records(sync_config_id),
         {:ok, _result} <- sync_to_provider(sync_config.provider, selected_records, credentials) do
      
      # Update sync status to completed
      update_sync_status(sync_config, :completed, DateTime.utc_now())
      Logger.info("Sync completed successfully for configuration: #{sync_config_id}")
      {:ok, :completed}
    else
      {:error, reason} = error ->
        Logger.error("Sync failed for configuration: #{sync_config_id}, reason: #{inspect(reason)}")
        
        # Update sync status to failed if we have the config
        case load_sync_configuration(sync_config_id) do
          {:ok, sync_config} -> update_sync_status(sync_config, :failed, DateTime.utc_now())
          _ -> :ok
        end
        
        error
    end
  end

  @doc """
  Test connection to a provider with given credentials.
  """
  def test_connection(provider, credentials) do
    case provider do
      :airtable -> test_airtable_connection(credentials)
      :notion -> test_notion_connection(credentials)
      :zapier -> test_zapier_connection(credentials)
      _ -> {:error, :unsupported_provider}
    end
  end

  # Private functions

  defp load_sync_configuration(sync_config_id) do
    case Ash.get(SyncConfiguration, sync_config_id, domain: Sertantai.Sync) do
      {:ok, config} -> {:ok, config}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :sync_config_not_found}
      {:error, error} -> {:error, error}
    end
  end

  defp decrypt_credentials(sync_config) do
    case SyncConfiguration.decrypt_credentials(sync_config) do
      {:ok, credentials} -> {:ok, credentials}
      {:error, reason} -> {:error, {:credential_decryption_failed, reason}}
    end
  end

  defp load_selected_records(sync_config_id) do
    case Ash.read(
      SelectedRecord
      |> Ash.Query.filter(expr(sync_configuration_id == ^sync_config_id)),
      domain: Sertantai.Sync
    ) do
      {:ok, records} -> {:ok, records}
      {:error, error} -> {:error, {:failed_to_load_records, error}}
    end
  end

  defp sync_to_provider(provider, records, credentials) do
    case provider do
      :airtable -> sync_to_airtable(records, credentials)
      :notion -> sync_to_notion(records, credentials)
      :zapier -> sync_to_zapier(records, credentials)
      _ -> {:error, :unsupported_provider}
    end
  end

  defp update_sync_status(sync_config, status, timestamp) do
    case Ash.update(sync_config, %{
      sync_status: status,
      last_synced_at: timestamp
    }, domain: Sertantai.Sync) do
      {:ok, _} -> :ok
      {:error, error} -> 
        Logger.error("Failed to update sync status: #{inspect(error)}")
        :error
    end
  end

  # Airtable API Integration
  defp sync_to_airtable(records, credentials) do
    Logger.info("Syncing #{length(records)} records to Airtable")
    
    base_url = "https://api.airtable.com/v0/#{credentials["base_id"]}/#{credentials["table_id"]}"
    headers = [
      {"Authorization", "Bearer #{credentials["api_key"]}"},
      {"Content-Type", "application/json"}
    ]

    # Convert records to Airtable format
    airtable_records = Enum.map(records, &format_record_for_airtable/1)
    
    # Batch records (Airtable accepts up to 10 records per request)
    airtable_records
    |> Enum.chunk_every(10)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
      case create_airtable_records(base_url, headers, batch) do
        {:ok, created_records} -> {:cont, {:ok, acc ++ created_records}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp create_airtable_records(base_url, headers, records) do
    body = Jason.encode!(%{"records" => records})
    
    request = Finch.build(:post, base_url, headers, body)
    
    case Finch.request(request, Sertantai.Finch) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"records" => created_records}} -> {:ok, created_records}
          {:error, _} -> {:error, :invalid_response_format}
        end
      
      {:ok, %Finch.Response{status: status_code, body: error_body}} ->
        Logger.error("Airtable API error: #{status_code} - #{error_body}")
        {:error, {:airtable_api_error, status_code, error_body}}
      
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, {:http_request_failed, reason}}
    end
  end

  defp format_record_for_airtable(record) do
    %{
      "fields" => %{
        "Record ID" => record.external_record_id,
        "Record Type" => record.record_type,
        "Data" => Jason.encode!(record.cached_data || %{}),
        "Sync Status" => to_string(record.sync_status),
        "Last Synced" => if(record.last_synced_at, do: DateTime.to_iso8601(record.last_synced_at), else: nil)
      }
    }
  end

  defp test_airtable_connection(credentials) do
    base_url = "https://api.airtable.com/v0/#{credentials["base_id"]}/#{credentials["table_id"]}"
    headers = [
      {"Authorization", "Bearer #{credentials["api_key"]}"}
    ]

    request = Finch.build(:get, "#{base_url}?maxRecords=1", headers)
    
    case Finch.request(request, Sertantai.Finch) do
      {:ok, %Finch.Response{status: 200}} -> {:ok, :connected}
      {:ok, %Finch.Response{status: 401}} -> {:error, :unauthorized}
      {:ok, %Finch.Response{status: 404}} -> {:error, :not_found}
      {:ok, %Finch.Response{status: status_code}} -> {:error, {:unexpected_status, status_code}}
      {:error, reason} -> {:error, {:connection_failed, reason}}
    end
  end

  # Notion API Integration
  defp sync_to_notion(records, credentials) do
    Logger.info("Syncing #{length(records)} records to Notion")
    
    database_url = "https://api.notion.com/v1/pages"
    headers = [
      {"Authorization", "Bearer #{credentials["api_key"]}"},
      {"Content-Type", "application/json"},
      {"Notion-Version", "2022-06-28"}
    ]

    # Sync each record individually to Notion
    records
    |> Enum.reduce_while({:ok, []}, fn record, {:ok, acc} ->
      case create_notion_page(database_url, headers, record, credentials["database_id"]) do
        {:ok, created_page} -> {:cont, {:ok, acc ++ [created_page]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp create_notion_page(url, headers, record, database_id) do
    body = Jason.encode!(%{
      "parent" => %{"database_id" => database_id},
      "properties" => format_record_for_notion(record)
    })
    
    request = Finch.build(:post, url, headers, body)
    
    case Finch.request(request, Sertantai.Finch) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, page_data} -> {:ok, page_data}
          {:error, _} -> {:error, :invalid_response_format}
        end
      
      {:ok, %Finch.Response{status: status_code, body: error_body}} ->
        Logger.error("Notion API error: #{status_code} - #{error_body}")
        {:error, {:notion_api_error, status_code, error_body}}
      
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, {:http_request_failed, reason}}
    end
  end

  defp format_record_for_notion(record) do
    %{
      "Record ID" => %{
        "title" => [%{
          "text" => %{"content" => record.external_record_id}
        }]
      },
      "Record Type" => %{
        "rich_text" => [%{
          "text" => %{"content" => record.record_type}
        }]
      },
      "Sync Status" => %{
        "select" => %{"name" => String.capitalize(to_string(record.sync_status))}
      }
    }
  end

  defp test_notion_connection(credentials) do
    url = "https://api.notion.com/v1/databases/#{credentials["database_id"]}"
    headers = [
      {"Authorization", "Bearer #{credentials["api_key"]}"},
      {"Notion-Version", "2022-06-28"}
    ]

    request = Finch.build(:get, url, headers)
    
    case Finch.request(request, Sertantai.Finch) do
      {:ok, %Finch.Response{status: 200}} -> {:ok, :connected}
      {:ok, %Finch.Response{status: 401}} -> {:error, :unauthorized}
      {:ok, %Finch.Response{status: 404}} -> {:error, :not_found}
      {:ok, %Finch.Response{status: status_code}} -> {:error, {:unexpected_status, status_code}}
      {:error, reason} -> {:error, {:connection_failed, reason}}
    end
  end

  # Zapier Webhook Integration
  defp sync_to_zapier(records, credentials) do
    Logger.info("Syncing #{length(records)} records to Zapier webhook")
    
    webhook_url = credentials["webhook_url"]
    headers = [
      {"Content-Type", "application/json"}
    ]

    # Add API key to headers if provided
    headers = if credentials["api_key"] do
      [{"Authorization", "Bearer #{credentials["api_key"]}"} | headers]
    else
      headers
    end

    # Send all records in a single webhook call
    webhook_data = %{
      "records" => Enum.map(records, &format_record_for_zapier/1),
      "sync_timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "record_count" => length(records)
    }

    body = Jason.encode!(webhook_data)
    
    request = Finch.build(:post, webhook_url, headers, body)
    
    case Finch.request(request, Sertantai.Finch) do
      {:ok, %Finch.Response{status: status_code}} when status_code in 200..299 ->
        {:ok, :webhook_sent}
      
      {:ok, %Finch.Response{status: status_code, body: error_body}} ->
        Logger.error("Zapier webhook error: #{status_code} - #{error_body}")
        {:error, {:zapier_webhook_error, status_code, error_body}}
      
      {:error, reason} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, {:http_request_failed, reason}}
    end
  end

  defp format_record_for_zapier(record) do
    %{
      "record_id" => record.external_record_id,
      "record_type" => record.record_type,
      "cached_data" => record.cached_data || %{},
      "sync_status" => to_string(record.sync_status),
      "last_synced_at" => if(record.last_synced_at, do: DateTime.to_iso8601(record.last_synced_at), else: nil)
    }
  end

  defp test_zapier_connection(credentials) do
    webhook_url = credentials["webhook_url"]
    headers = [{"Content-Type", "application/json"}]

    # Add API key to headers if provided
    headers = if credentials["api_key"] do
      [{"Authorization", "Bearer #{credentials["api_key"]}"} | headers]
    else
      headers
    end

    # Send a test payload
    test_data = %{
      "test" => true,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    body = Jason.encode!(test_data)
    
    request = Finch.build(:post, webhook_url, headers, body)
    
    case Finch.request(request, Sertantai.Finch) do
      {:ok, %Finch.Response{status: status_code}} when status_code in 200..299 ->
        {:ok, :connected}
      {:ok, %Finch.Response{status: status_code}} ->
        {:error, {:unexpected_status, status_code}}
      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end
end