defmodule Sertantai.Query.ResultStreamer do
  @moduledoc """
  Phase 2 Result Streaming architecture for progressive result delivery.
  
  Provides streaming capabilities for real-time applicability screening results
  with efficient LiveView updates and result diffing.
  """

  alias Sertantai.Query.ProgressiveQueryBuilder
  alias Phoenix.PubSub

  @pubsub_topic_prefix "applicability_results"

  @doc """
  Initiates progressive result streaming for an organization.
  Returns a stream reference and starts background processing.
  """
  def start_progressive_stream(organization, subscriber_pid, opts \\ []) do
    stream_id = generate_stream_id(organization)
    topic = build_stream_topic(stream_id)
    
    # Subscribe the caller to updates
    PubSub.subscribe(Sertantai.PubSub, topic)
    
    # Start background streaming process
    {:ok, _pid} = Task.start_link(fn ->
      execute_progressive_stream(organization, stream_id, opts)
    end)
    
    %{
      stream_id: stream_id,
      topic: topic,
      status: :initiated,
      subscriber_count: 1
    }
  end

  @doc """
  Subscribes to an existing progressive result stream.
  """
  def subscribe_to_stream(stream_id) do
    topic = build_stream_topic(stream_id)
    PubSub.subscribe(Sertantai.PubSub, topic)
    
    %{
      stream_id: stream_id,
      topic: topic,
      status: :subscribed
    }
  end

  @doc """
  Unsubscribes from a progressive result stream.
  """
  def unsubscribe_from_stream(stream_id) do
    topic = build_stream_topic(stream_id)
    PubSub.unsubscribe(Sertantai.PubSub, topic)
    :ok
  end

  @doc """
  Compares two result sets and returns a diff for efficient LiveView updates.
  """
  def calculate_result_diff(previous_results, new_results) do
    previous_ids = extract_regulation_ids(previous_results)
    new_ids = extract_regulation_ids(new_results)
    
    added_ids = new_ids -- previous_ids
    removed_ids = previous_ids -- new_ids
    unchanged_ids = new_ids -- added_ids
    
    %{
      added: filter_regulations_by_ids(new_results, added_ids),
      removed: filter_regulations_by_ids(previous_results, removed_ids),
      unchanged_count: length(unchanged_ids),
      total_changes: length(added_ids) + length(removed_ids),
      change_summary: %{
        added_count: length(added_ids),
        removed_count: length(removed_ids),
        total_current: length(new_ids)
      }
    }
  end

  @doc """
  Generates real-time applicability updates for organization profile changes.
  """
  def handle_profile_update(organization, changed_fields) do
    stream_id = generate_stream_id(organization)
    topic = build_stream_topic(stream_id)
    
    # Calculate impact of profile changes
    impact_analysis = analyze_profile_change_impact(organization, changed_fields)
    
    # If significant impact, trigger progressive re-screening
    if impact_analysis.requires_rescreening do
      broadcast_profile_change_notification(topic, impact_analysis)
      start_progressive_stream(organization, self(), [trigger: :profile_update])
    else
      broadcast_minor_update(topic, impact_analysis)
    end
    
    impact_analysis
  end

  # Private implementation functions

  defp execute_progressive_stream(organization, stream_id, opts) do
    topic = build_stream_topic(stream_id)
    
    # Broadcast stream initiation
    broadcast_stream_event(topic, :stream_started, %{
      stream_id: stream_id,
      organization_id: extract_organization_id(organization),
      timestamp: DateTime.utc_now()
    })
    
    try do
      # Phase 1: Quick basic screening
      broadcast_stream_event(topic, :phase_started, %{phase: :basic})
      basic_results = execute_basic_phase(organization)
      broadcast_stream_event(topic, :phase_completed, %{
        phase: :basic,
        results: basic_results,
        next_phase: :enhanced
      })
      
      # Phase 2: Enhanced screening if profile supports it
      if should_proceed_to_enhanced?(organization) do
        broadcast_stream_event(topic, :phase_started, %{phase: :enhanced})
        enhanced_results = execute_enhanced_phase(organization, basic_results)
        broadcast_stream_event(topic, :phase_completed, %{
          phase: :enhanced,
          results: enhanced_results,
          next_phase: :comprehensive
        })
        
        # Phase 3: Comprehensive analysis if warranted
        if should_proceed_to_comprehensive?(organization) do
          broadcast_stream_event(topic, :phase_started, %{phase: :comprehensive})
          comprehensive_results = execute_comprehensive_phase(organization, enhanced_results)
          broadcast_stream_event(topic, :phase_completed, %{
            phase: :comprehensive,
            results: comprehensive_results,
            next_phase: nil
          })
        end
      end
      
      # Broadcast stream completion
      broadcast_stream_event(topic, :stream_completed, %{
        stream_id: stream_id,
        total_phases: count_completed_phases(organization),
        timestamp: DateTime.utc_now()
      })
      
    rescue
      error ->
        broadcast_stream_event(topic, :stream_error, %{
          stream_id: stream_id,
          error: Exception.message(error),
          timestamp: DateTime.utc_now()
        })
    end
  end

  defp execute_basic_phase(organization) do
    # Execute basic screening with minimal data requirements
    strategy = ProgressiveQueryBuilder.build_query_strategy(organization)
    
    case strategy.complexity_level do
      level when level in [:basic, :enhanced, :comprehensive] ->
        ProgressiveQueryBuilder.execute_progressive_screening(organization, [phase: :basic])
      _ ->
        %{error: "Insufficient organization data for basic screening"}
    end
  end

  defp execute_enhanced_phase(organization, basic_results) do
    # Execute enhanced screening with additional filtering
    enhanced_results = ProgressiveQueryBuilder.execute_progressive_screening(organization, [phase: :enhanced])
    
    # Calculate diff from basic results
    diff = calculate_result_diff(
      Map.get(basic_results, :sample_regulations, []),
      Map.get(enhanced_results, :sample_regulations, [])
    )
    
    Map.put(enhanced_results, :diff_from_basic, diff)
  end

  defp execute_comprehensive_phase(organization, enhanced_results) do
    # Execute comprehensive screening with full analysis
    comprehensive_results = ProgressiveQueryBuilder.execute_progressive_screening(organization, [phase: :comprehensive])
    
    # Calculate diff from enhanced results
    diff = calculate_result_diff(
      Map.get(enhanced_results, :sample_regulations, []),
      Map.get(comprehensive_results, :sample_regulations, [])
    )
    
    Map.put(comprehensive_results, :diff_from_enhanced, diff)
  end

  defp should_proceed_to_enhanced?(organization) do
    complexity_score = ProgressiveQueryBuilder.calculate_query_complexity_score(organization)
    complexity_score.total_score >= 0.5
  end

  defp should_proceed_to_comprehensive?(organization) do
    complexity_score = ProgressiveQueryBuilder.calculate_query_complexity_score(organization)
    complexity_score.total_score >= 0.8
  end

  defp count_completed_phases(organization) do
    cond do
      should_proceed_to_comprehensive?(organization) -> 3
      should_proceed_to_enhanced?(organization) -> 2
      true -> 1
    end
  end

  defp generate_stream_id(organization) do
    org_id = extract_organization_id(organization)
    timestamp = System.system_time(:microsecond)
    "stream_#{org_id}_#{timestamp}"
  end

  defp build_stream_topic(stream_id) do
    "#{@pubsub_topic_prefix}:#{stream_id}"
  end

  defp extract_organization_id(organization) do
    case organization do
      %{id: id} -> id
      %{"id" => id} -> id
      _ -> :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    end
  end

  defp extract_regulation_ids(results) when is_map(results) do
    case Map.get(results, :sample_regulations) do
      regulations when is_list(regulations) ->
        Enum.map(regulations, fn reg -> Map.get(reg, :id) end)
        |> Enum.reject(&is_nil/1)
      _ -> []
    end
  end
  defp extract_regulation_ids(_), do: []

  defp filter_regulations_by_ids(results, ids) when is_map(results) do
    case Map.get(results, :sample_regulations) do
      regulations when is_list(regulations) ->
        Enum.filter(regulations, fn reg -> Map.get(reg, :id) in ids end)
      _ -> []
    end
  end
  defp filter_regulations_by_ids(_, _), do: []

  defp analyze_profile_change_impact(organization, changed_fields) do
    # Analyze which fields changed and their impact on screening results
    critical_fields = ["industry_sector", "headquarters_region", "total_employees"]
    enhanced_fields = ["operational_regions", "business_activities", "annual_turnover"]
    
    critical_changes = Enum.any?(changed_fields, &(&1 in critical_fields))
    enhanced_changes = Enum.any?(changed_fields, &(&1 in enhanced_fields))
    
    %{
      requires_rescreening: critical_changes,
      impact_level: determine_impact_level(critical_changes, enhanced_changes),
      changed_fields: changed_fields,
      estimated_result_change: estimate_result_change(changed_fields),
      recommendation: generate_update_recommendation(critical_changes, enhanced_changes)
    }
  end

  defp determine_impact_level(true, _), do: :high
  defp determine_impact_level(false, true), do: :medium
  defp determine_impact_level(false, false), do: :low

  defp estimate_result_change(changed_fields) do
    # Estimate percentage of results that might change
    impact_weights = %{
      "industry_sector" => 0.8,
      "headquarters_region" => 0.6,
      "total_employees" => 0.4,
      "operational_regions" => 0.3,
      "business_activities" => 0.2,
      "annual_turnover" => 0.1
    }
    
    total_impact = changed_fields
    |> Enum.map(&Map.get(impact_weights, &1, 0.05))
    |> Enum.sum()
    |> min(1.0)
    
    round(total_impact * 100)
  end

  defp generate_update_recommendation(true, _) do
    "Profile changes significantly impact applicability screening. Full re-screening recommended."
  end
  defp generate_update_recommendation(false, true) do
    "Profile changes may affect screening accuracy. Enhanced screening recommended."
  end
  defp generate_update_recommendation(false, false) do
    "Minor profile changes. Current screening results remain valid."
  end

  defp broadcast_stream_event(topic, event_type, data) do
    PubSub.broadcast(Sertantai.PubSub, topic, {
      :applicability_stream_event,
      event_type,
      Map.merge(data, %{timestamp: DateTime.utc_now()})
    })
  end

  defp broadcast_profile_change_notification(topic, impact_analysis) do
    PubSub.broadcast(Sertantai.PubSub, topic, {
      :profile_change_notification,
      impact_analysis
    })
  end

  defp broadcast_minor_update(topic, impact_analysis) do
    PubSub.broadcast(Sertantai.PubSub, topic, {
      :minor_profile_update,
      impact_analysis
    })
  end
end