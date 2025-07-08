defmodule Sertantai.DataTransformers do
  @moduledoc """
  Data transformation functions for external sync integrations.
  Supports Baserow, Airtable, and other external service formats.
  """

  @doc """
  Transform UK LRT records to Baserow format.
  """
  def to_baserow_format(records) when is_list(records) do
    %{
      rows: Enum.map(records, &transform_record_to_baserow/1),
      metadata: %{
        total_records: length(records),
        transformed_at: DateTime.utc_now(),
        format: "baserow"
      }
    }
  end

  @doc """
  Transform UK LRT records to Airtable format.
  """
  def to_airtable_format(records) when is_list(records) do
    %{
      records: Enum.map(records, &transform_record_to_airtable/1),
      metadata: %{
        total_records: length(records),
        transformed_at: DateTime.utc_now(),
        format: "airtable"
      }
    }
  end

  @doc """
  Transform UK LRT records to generic sync format.
  """
  def to_sync_format(records, format \\ "standard") when is_list(records) do
    case format do
      "baserow" -> to_baserow_format(records)
      "airtable" -> to_airtable_format(records)
      "standard" -> to_standard_format(records)
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  @doc """
  Generate sync summary statistics.
  """
  def generate_sync_summary(records) when is_list(records) do
    family_counts = 
      records
      |> Enum.group_by(& &1.family)
      |> Enum.map(fn {family, recs} -> {family || "Unknown", length(recs)} end)
      |> Enum.into(%{})

    status_counts = 
      records
      |> Enum.group_by(& &1.live)
      |> Enum.map(fn {status, recs} -> {status || "Unknown", length(recs)} end)
      |> Enum.into(%{})

    year_range = 
      records
      |> Enum.map(& &1.year)
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> nil
        years -> {Enum.min(years), Enum.max(years)}
      end

    %{
      total_records: length(records),
      family_distribution: family_counts,
      status_distribution: status_counts,
      year_range: year_range,
      has_tags: records |> Enum.count(&(!is_nil(&1.tags) and length(&1.tags) > 0)),
      has_roles: records |> Enum.count(&(!is_nil(&1.role) and length(&1.role) > 0)),
      generated_at: DateTime.utc_now()
    }
  end

  # Private transformation functions

  defp transform_record_to_baserow(record) do
    %{
      "UK LRT ID" => record.id,
      "Name" => record.name,
      "Family" => record.family,
      "Family II" => record.family_ii,
      "Year" => record.year,
      "Number" => record.number,
      "Status" => record.live,
      "Type Description" => record.type_desc,
      "Description" => record.md_description,
      "Tags" => format_array_for_baserow(record.tags),
      "Roles" => format_array_for_baserow(record.role),
      "Created At" => format_datetime_for_baserow(record.created_at)
    }
  end

  defp transform_record_to_airtable(record) do
    %{
      fields: %{
        "UK LRT ID" => record.id,
        "Name" => record.name,
        "Family" => record.family,
        "Family II" => record.family_ii,
        "Year" => record.year,
        "Number" => record.number,
        "Status" => record.live,
        "Type Description" => record.type_desc,
        "Description" => record.md_description,
        "Tags" => format_array_for_airtable(record.tags),
        "Roles" => format_array_for_airtable(record.role),
        "Created At" => format_datetime_for_airtable(record.created_at)
      }
    }
  end

  defp to_standard_format(records) do
    %{
      data: Enum.map(records, &transform_record_to_standard/1),
      metadata: %{
        total_records: length(records),
        transformed_at: DateTime.utc_now(),
        format: "standard"
      }
    }
  end

  defp transform_record_to_standard(record) do
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
      roles: record.role || [],
      created_at: record.created_at
    }
  end

  # Helper functions for format-specific transformations

  defp format_array_for_baserow(nil), do: ""
  defp format_array_for_baserow([]), do: ""
  defp format_array_for_baserow(array) when is_list(array) do
    Enum.join(array, ", ")
  end

  defp format_array_for_airtable(nil), do: []
  defp format_array_for_airtable([]), do: []
  defp format_array_for_airtable(array) when is_list(array), do: array

  defp format_datetime_for_baserow(nil), do: nil
  defp format_datetime_for_baserow(datetime) do
    DateTime.to_iso8601(datetime)
  end

  defp format_datetime_for_airtable(nil), do: nil
  defp format_datetime_for_airtable(datetime) do
    DateTime.to_iso8601(datetime)
  end
end