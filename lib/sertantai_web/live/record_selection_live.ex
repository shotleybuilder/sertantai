defmodule SertantaiWeb.RecordSelectionLive do
  @moduledoc """
  LiveView for UK LRT record selection and filtering.
  Allows users to filter records by family and family_ii fields and select records for export.
  """
  use SertantaiWeb, :live_view

  alias Sertantai.UkLrt

  @default_page_size 20

  def mount(_params, session, socket) do
    # Load selected records from session if available
    selected_records = case session["selected_record_ids"] do
      nil -> MapSet.new()
      ids when is_list(ids) -> MapSet.new(ids)
      _ -> MapSet.new()
    end

    {:ok,
     socket
     |> assign(:page_title, "UK LRT Record Selection")
     |> assign(:loading, false)
     |> assign(:records, [])
     |> assign(:selected_records, selected_records)
     |> assign(:total_count, 0)
     |> assign(:current_page, 1)
     |> assign(:page_size, @default_page_size)
     |> assign(:filters, %{family: "", family_ii: ""})
     |> assign(:family_options, [])
     |> assign(:family_ii_options, [])
     |> assign(:show_filters, true)
     |> assign(:max_selections, 1000)  # Add selection limit
     |> load_initial_data()}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_filters(socket, params)}
  end

  def handle_event("filter_change", %{"filters" => filters}, socket) do
    updated_socket =
      socket
      |> assign(:filters, filters)
      |> assign(:current_page, 1)
      |> assign(:loading, true)
      |> load_filtered_records()

    {:noreply, updated_socket}
  end

  def handle_event("page_change", %{"page" => page}, socket) do
    page_num = String.to_integer(page)
    
    updated_socket =
      socket
      |> assign(:current_page, page_num)
      |> assign(:loading, true)
      |> load_filtered_records()

    {:noreply, updated_socket}
  end

  def handle_event("toggle_record", %{"record_id" => record_id}, socket) do
    selected = socket.assigns.selected_records
    max_selections = socket.assigns.max_selections
    
    updated_selected =
      if MapSet.member?(selected, record_id) do
        MapSet.delete(selected, record_id)
      else
        if MapSet.size(selected) >= max_selections do
          selected  # Don't add if limit reached
        else
          MapSet.put(selected, record_id)
        end
      end

    updated_socket = 
      socket
      |> assign(:selected_records, updated_selected)
      |> persist_selections(updated_selected)

    {:noreply, updated_socket}
  end

  def handle_event("select_all_page", _params, socket) do
    current_record_ids = 
      socket.assigns.records
      |> Enum.map(& &1.id)
      |> MapSet.new()

    # Respect selection limit
    max_selections = socket.assigns.max_selections
    current_selected = socket.assigns.selected_records
    available_slots = max_selections - MapSet.size(current_selected)
    
    records_to_add = current_record_ids |> Enum.take(available_slots) |> MapSet.new()
    updated_selected = MapSet.union(current_selected, records_to_add)

    updated_socket = 
      socket
      |> assign(:selected_records, updated_selected)
      |> persist_selections(updated_selected)

    {:noreply, updated_socket}
  end

  def handle_event("deselect_all_page", _params, socket) do
    current_record_ids = 
      socket.assigns.records
      |> Enum.map(& &1.id)
      |> MapSet.new()

    updated_selected = MapSet.difference(socket.assigns.selected_records, current_record_ids)

    updated_socket = 
      socket
      |> assign(:selected_records, updated_selected)
      |> persist_selections(updated_selected)

    {:noreply, updated_socket}
  end

  def handle_event("clear_all_selections", _params, socket) do
    updated_socket = 
      socket
      |> assign(:selected_records, MapSet.new())
      |> persist_selections(MapSet.new())

    {:noreply, updated_socket}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :show_filters, !socket.assigns.show_filters)}
  end

  def handle_event("export_csv", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_records)
    
    if Enum.empty?(selected_ids) do
      {:noreply, put_flash(socket, :error, "No records selected for export")}
    else
      case export_selected_records(selected_ids, :csv) do
        {:ok, csv_data} ->
          # Trigger file download through JavaScript
          {:noreply, 
           socket 
           |> push_event("download-file", %{
             filename: "uk_lrt_records_#{Date.utc_today()}.csv",
             content: csv_data,
             mime_type: "text/csv"
           })
           |> put_flash(:info, "CSV export generated successfully")}
        
        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Export failed: #{inspect(error)}")}
      end
    end
  end

  def handle_event("export_json", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_records)
    
    if Enum.empty?(selected_ids) do
      {:noreply, put_flash(socket, :error, "No records selected for export")}
    else
      case export_selected_records(selected_ids, :json) do
        {:ok, json_data} ->
          # Trigger file download through JavaScript
          {:noreply, 
           socket 
           |> push_event("download-file", %{
             filename: "uk_lrt_records_#{Date.utc_today()}.json",
             content: json_data,
             mime_type: "application/json"
           })
           |> put_flash(:info, "JSON export generated successfully")}
        
        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Export failed: #{inspect(error)}")}
      end
    end
  end

  # Private functions

  defp load_initial_data(socket) do
    # Load family options
    case Ash.read(UkLrt |> Ash.Query.for_read(:distinct_families), domain: Sertantai.Domain) do
      {:ok, families} ->
        family_options = 
          families
          |> Enum.map(& &1.family)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort()

        socket
        |> assign(:family_options, family_options)
        |> load_family_ii_options()
        |> load_filtered_records()

      {:error, _error} ->
        socket
        |> assign(:family_options, [])
        |> put_flash(:error, "Failed to load family options")
    end
  end

  defp load_family_ii_options(socket) do
    case Ash.read(UkLrt |> Ash.Query.for_read(:distinct_family_ii), domain: Sertantai.Domain) do
      {:ok, family_ii_records} ->
        family_ii_options = 
          family_ii_records
          |> Enum.map(& &1.family_ii)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort()

        assign(socket, :family_ii_options, family_ii_options)

      {:error, _error} ->
        socket
        |> assign(:family_ii_options, [])
        |> put_flash(:error, "Failed to load family_ii options")
    end
  end

  defp load_filtered_records(socket) do
    filters = socket.assigns.filters
    page = socket.assigns.current_page
    page_size = socket.assigns.page_size

    # Build query with filters
    query = build_filtered_query(filters, page, page_size)

    case Ash.read(query, domain: Sertantai.Domain) do
      {:ok, %{results: records, count: count}} ->
        socket
        |> assign(:records, records)
        |> assign(:total_count, count || 0)
        |> assign(:loading, false)

      {:ok, records} when is_list(records) ->
        # Fallback for non-paginated results
        socket
        |> assign(:records, records)
        |> assign(:total_count, length(records))
        |> assign(:loading, false)

      {:error, error} ->
        socket
        |> assign(:records, [])
        |> assign(:total_count, 0)
        |> assign(:loading, false)
        |> put_flash(:error, "Failed to load records: #{inspect(error)}")
    end
  end

  defp build_filtered_query(filters, page, page_size) do
    family = if filters["family"] != "", do: filters["family"], else: nil
    family_ii = if filters["family_ii"] != "", do: filters["family_ii"], else: nil

    cond do
      family && family_ii ->
        UkLrt |> Ash.Query.for_read(:by_families, %{family: family, family_ii: family_ii})

      family ->
        UkLrt |> Ash.Query.for_read(:by_family, %{family: family})

      family_ii ->
        UkLrt |> Ash.Query.for_read(:by_family_ii, %{family_ii: family_ii})

      true ->
        UkLrt |> Ash.Query.for_read(:read)
    end
    |> Ash.Query.page(offset: (page - 1) * page_size, limit: page_size, count: true)
  end

  defp apply_filters(socket, params) do
    filters = %{
      "family" => params["family"] || "",
      "family_ii" => params["family_ii"] || ""
    }

    socket
    |> assign(:filters, filters)
    |> load_filtered_records()
  end

  # Helper functions for template

  defp selected_count(selected_records) do
    MapSet.size(selected_records)
  end

  defp is_selected?(selected_records, record_id) do
    MapSet.member?(selected_records, record_id)
  end

  defp total_pages(total_count, page_size) do
    ceil(total_count / page_size)
  end

  defp format_status(status) do
    case status do
      "✔ In force" -> {:ok, "In Force"}
      "❌ Revoked / Repealed / Abolished" -> {:error, "Revoked"}
      "⭕ Part Revocation / Repeal" -> {:warning, "Partially Revoked"}
      _ -> {:neutral, status || "Unknown"}
    end
  end

  defp format_year(year) when is_integer(year), do: to_string(year)
  defp format_year(year) when is_binary(year), do: year
  defp format_year(_), do: ""

  # Session persistence helper
  defp persist_selections(socket, selected_records) do
    selected_ids = MapSet.to_list(selected_records)
    # For now, we'll store in socket assigns instead of session
    # Session storage can be implemented later with proper session management
    assign(socket, :selected_records_persistent, selected_ids)
  end

  # Export functionality
  defp export_selected_records(selected_ids, format) do
    # Fetch selected records from database
    case fetch_records_by_ids(selected_ids) do
      {:ok, records} ->
        case format do
          :csv -> {:ok, generate_csv(records)}
          :json -> {:ok, generate_json(records)}
        end
      
      {:error, error} ->
        {:error, error}
    end
  end

  defp fetch_records_by_ids(record_ids) do
    query = UkLrt |> Ash.Query.for_read(:for_sync, %{record_ids: record_ids})
    
    case Ash.read(query, domain: Sertantai.Domain) do
      {:ok, records} -> {:ok, records}
      {:error, error} -> {:error, error}
    end
  end

  defp generate_csv(records) do
    headers = ["ID", "Name", "Family", "Family II", "Year", "Number", "Status", "Type", "Description", "Tags", "Role", "Created At"]
    
    csv_data = 
      [headers | Enum.map(records, &record_to_csv_row/1)]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")
    
    csv_data
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
      escape_csv_field(record.md_description || ""),
      escape_csv_field(inspect(record.tags || [])),
      escape_csv_field(inspect(record.role || [])),
      record.created_at || ""
    ]
  end

  defp escape_csv_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp generate_json(records) do
    records
    |> Enum.map(&record_to_map/1)
    |> Jason.encode!()
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
      role: record.role || [],
      created_at: record.created_at
    }
  end

end