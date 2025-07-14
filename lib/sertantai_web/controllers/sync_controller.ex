defmodule SertantaiWeb.SyncController do
  @moduledoc """
  API endpoints for sync tools to access user's selected records.
  """
  use SertantaiWeb, :controller
  
  alias SertantaiWeb.RecordSelectionLive
  alias Sertantai.UserSelections

  @doc """
  Get selected record IDs for the authenticated user.
  Returns JSON array of record IDs.
  """
  def selected_ids(conn, _params) do
    case conn.assigns[:current_user] do
      %{id: user_id} ->
        selected_ids = UserSelections.get_selections(user_id)
        json(conn, %{selected_ids: selected_ids, count: length(selected_ids)})
      
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  @doc """
  Get full selected record data for the authenticated user.
  Returns JSON array of complete record objects.
  """
  def selected_records(conn, _params) do
    case conn.assigns[:current_user] do
      %{id: user_id} ->
        case RecordSelectionLive.get_user_selected_records(user_id) do
          {:ok, records} ->
            json(conn, %{
              records: records, 
              count: length(records),
              selected_at: DateTime.utc_now()
            })
          
          {:error, error} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to fetch records: #{inspect(error)}"})
        end
      
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  @doc """
  Export selected records in specified format (CSV or JSON).
  """
  def export(conn, %{"format" => format}) when format in ["csv", "json"] do
    case conn.assigns[:current_user] do
      %{id: user_id} ->
        selected_ids = UserSelections.get_selections(user_id)
        
        if Enum.empty?(selected_ids) do
          conn
          |> put_status(:bad_request)
          |> json(%{error: "No records selected"})
        else
          # Use the existing export functionality from RecordSelectionLive
          format_atom = String.to_atom(format)
          
          case RecordSelectionLive.get_user_selected_records(user_id) do
            {:ok, records} ->
              {:ok, data} = export_records(records, format_atom)
              content_type = if format == "csv", do: "text/csv", else: "application/json"
              filename = "sertantai_records_#{Date.utc_today()}.#{format}"
              
              conn
              |> put_resp_content_type(content_type)
              |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
              |> send_resp(200, data)
            
            {:error, error} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "Failed to fetch records: #{inspect(error)}"})
          end
        end
      
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  def export(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid format. Supported formats: csv, json"})
  end

  # Helper function for export
  defp export_records(records, :csv) do
    headers = ["ID", "Name", "Family", "Family II", "Year", "Number", "Status", "Type", "Description"]
    
    csv_data = 
      [headers | Enum.map(records, &record_to_csv_row/1)]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")
    
    {:ok, csv_data}
  end

  defp export_records(records, :json) do
    data = Enum.map(records, &record_to_map/1)
    {:ok, Jason.encode!(data)}
  end

  defp record_to_csv_row(record) do
    [
      record.id || "",
      escape_csv_field(record.name || ""),
      escape_csv_field(record.family || ""),
      escape_csv_field(record.family_ii || ""),
      record.year || "",
      escape_csv_field(record.number || ""),
      escape_csv_field(record.live || ""),
      escape_csv_field(record.type_desc || ""),
      escape_csv_field(record.md_description || "")
    ]
  end

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      escaped = String.replace(value, "\"", "\"\"")
      "\"#{escaped}\""
    else
      value
    end
  end

  defp record_to_map(record) do
    %{
      id: record.id,
      name: record.name,
      family: record.family,
      family_ii: record.family_ii,
      year: record.year,
      number: record.number,
      status: record.live,
      type_description: record.type_desc,
      description: record.md_description,
      tags: record.tags || [],
      role: record.role || []
    }
  end
end