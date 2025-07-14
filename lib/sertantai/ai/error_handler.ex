defmodule Sertantai.AI.ErrorHandler do
  @moduledoc """
  Comprehensive error handling and fallback mechanisms for AI services.
  
  Provides graceful degradation, error recovery, and fallback responses
  when AI services encounter issues.
  """

  require Logger

  alias Sertantai.AI.ConversationSession

  @error_types %{
    network_error: "network_error",
    service_timeout: "service_timeout", 
    api_rate_limit: "api_rate_limit",
    invalid_response: "invalid_response",
    authentication_error: "authentication_error",
    service_unavailable: "service_unavailable",
    unexpected_error: "unexpected_error"
  }

  @fallback_responses %{
    question_generation: [
      "Could you tell me more about your organization's main activities?",
      "What industry sector does your organization operate in?",
      "How many employees does your organization have?",
      "What geographical regions do you operate in?"
    ],
    gap_analysis: %{
      missing_critical_fields: ["business_activities", "operational_regions", "industry_sector"],
      confidence_score: 0.5,
      completeness_percentage: 30,
      fallback_used: true
    },
    entity_extraction: %{
      extracted_fields: %{},
      confidence_scores: %{},
      clarifications_needed: ["I didn't quite catch that. Could you rephrase your response?"],
      extraction_notes: "Using fallback - please be more specific",
      validation_warnings: ["Fallback mode active"]
    }
  }

  def handle_ai_error(error, context \\ %{})

  def handle_ai_error(%{__exception__: true} = exception, context) do
    error_type = classify_exception(exception)
    handle_classified_error(error_type, exception, context)
  end

  def handle_ai_error(error_atom, context) when is_atom(error_atom) do
    handle_classified_error(error_atom, nil, context)
  end

  def handle_ai_error(error_string, context) when is_binary(error_string) do
    error_type = classify_error_message(error_string)
    handle_classified_error(error_type, error_string, context)
  end

  def handle_ai_error(error, context) do
    Logger.error("Unclassified AI error: #{inspect(error)}, context: #{inspect(context)}")
    handle_classified_error(:unexpected_error, error, context)
  end

  def get_fallback_response(service_type, context \\ %{})

  def get_fallback_response(:question_generation, context) do
    questions = @fallback_responses.question_generation
    
    # Select appropriate fallback question based on context
    selected_question = case context do
      %{conversation_history: []} ->
        "Let's start with the basics. What is your organization's primary business activity?"
      
      %{missing_fields: fields} when is_list(fields) ->
        select_question_for_missing_field(List.first(fields))
      
      _ ->
        Enum.random(questions)
    end

    %{
      question_text: selected_question,
      target_field: "general_information",
      priority: "medium",
      question_type: "fallback",
      fallback_reason: "AI service unavailable"
    }
  end

  def get_fallback_response(:gap_analysis, context) do
    base_response = @fallback_responses.gap_analysis
    
    # Customize based on available organization data
    case context do
      %{organization_profile: profile} when is_map(profile) ->
        missing_fields = identify_basic_missing_fields(profile)
        %{base_response | missing_critical_fields: missing_fields}
      
      _ ->
        base_response
    end
  end

  def get_fallback_response(:entity_extraction, context) do
    base_response = @fallback_responses.entity_extraction
    
    # Try basic extraction if we have user response
    case context do
      %{user_response: response} when is_binary(response) ->
        basic_extraction = attempt_basic_extraction(response)
        Map.merge(base_response, basic_extraction)
      
      _ ->
        base_response
    end
  end

  def get_fallback_response(service_type, _context) do
    Logger.warning("No fallback available for service type: #{service_type}")
    %{
      error: "Service temporarily unavailable",
      fallback_used: true,
      service_type: service_type
    }
  end

  def should_retry?(error_type, attempt_count \\ 1)

  def should_retry?(:network_error, attempt_count) when attempt_count < 3, do: true
  def should_retry?(:service_timeout, attempt_count) when attempt_count < 2, do: true
  def should_retry?(:service_unavailable, attempt_count) when attempt_count < 2, do: true
  def should_retry?(:api_rate_limit, attempt_count) when attempt_count < 1, do: true
  def should_retry?(_, _), do: false

  def get_retry_delay(error_type, attempt_count \\ 1)

  def get_retry_delay(:network_error, attempt_count), do: attempt_count * 1000
  def get_retry_delay(:service_timeout, attempt_count), do: attempt_count * 2000
  def get_retry_delay(:api_rate_limit, _), do: 60000  # 1 minute
  def get_retry_delay(:service_unavailable, attempt_count), do: attempt_count * 5000
  def get_retry_delay(_, _), do: 1000

  def handle_session_interruption(session_id, error_type, error_details \\ nil) do
    case ConversationSession.read(session_id) do
      {:ok, session} ->
        reason = format_interruption_reason(error_type, error_details)
        ConversationSession.mark_interrupted(session, reason)
        
        Logger.warning("Session #{session_id} interrupted: #{reason}")
        {:ok, :session_interrupted}
      
      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.error("Cannot interrupt session #{session_id}: session not found")
        {:error, :session_not_found}
      
      {:error, error} ->
        Logger.error("Failed to interrupt session #{session_id}: #{inspect(error)}")
        {:error, :interruption_failed}
    end
  end

  def attempt_session_recovery(session_id) do
    case ConversationSession.read(session_id) do
      {:ok, session} when session.session_status == :interrupted ->
        case ConversationSession.recover_session(session) do
          {:ok, recovered_session} ->
            Logger.info("Session #{session_id} successfully recovered")
            {:ok, recovered_session}
          
          {:error, error} ->
            Logger.error("Failed to recover session #{session_id}: #{inspect(error)}")
            {:error, :recovery_failed}
        end
      
      {:ok, session} ->
        Logger.info("Session #{session_id} does not need recovery (status: #{session.session_status})")
        {:ok, session}
      
      {:error, error} ->
        Logger.error("Cannot recover session #{session_id}: #{inspect(error)}")
        {:error, :session_not_found}
    end
  end

  def monitor_service_health(service_name, health_check_fn) do
    try do
      case health_check_fn.() do
        :ok ->
          update_service_status(service_name, :healthy)
          {:ok, :healthy}
        
        {:error, reason} ->
          update_service_status(service_name, :degraded, reason)
          {:error, :degraded}
        
        :timeout ->
          update_service_status(service_name, :unhealthy, "Service timeout")
          {:error, :unhealthy}
      end
    rescue
      exception ->
        update_service_status(service_name, :unhealthy, "Health check failed: #{inspect(exception)}")
        {:error, :unhealthy}
    end
  end

  # Private helper functions

  defp classify_exception(%{__struct__: struct_name} = exception) do
    case struct_name do
      module when module in [HTTPoison.Error, Req.TransportError] ->
        :network_error
      
      module when module in [HTTPoison.TimeoutError, Req.TimeoutError] ->
        :service_timeout
      
      Tesla.Error ->
        classify_tesla_error(exception)
      
      _ ->
        :unexpected_error
    end
  end

  defp classify_tesla_error(%{reason: reason}) do
    case reason do
      :timeout -> :service_timeout
      :econnrefused -> :network_error
      :nxdomain -> :network_error
      _ -> :unexpected_error
    end
  end

  defp classify_error_message(message) when is_binary(message) do
    message_lower = String.downcase(message)
    
    cond do
      String.contains?(message_lower, ["timeout", "timed out"]) ->
        :service_timeout
      
      String.contains?(message_lower, ["rate limit", "quota exceeded"]) ->
        :api_rate_limit
      
      String.contains?(message_lower, ["network", "connection", "unreachable"]) ->
        :network_error
      
      String.contains?(message_lower, ["unauthorized", "authentication", "api key"]) ->
        :authentication_error
      
      String.contains?(message_lower, ["service unavailable", "server error", "503", "502"]) ->
        :service_unavailable
      
      String.contains?(message_lower, ["invalid response", "malformed", "parse error"]) ->
        :invalid_response
      
      true ->
        :unexpected_error
    end
  end

  defp handle_classified_error(error_type, error_details, context) do
    Logger.error("AI service error: #{error_type}, details: #{inspect(error_details)}")
    
    # Mark session as interrupted if session_id provided
    if context[:session_id] do
      handle_session_interruption(context.session_id, error_type, error_details)
    end
    
    # Return appropriate response based on error type and context
    response = %{
      error_type: error_type,
      should_retry: should_retry?(error_type),
      retry_delay: get_retry_delay(error_type),
      fallback_available: has_fallback?(context[:service_type]),
      recovery_suggestions: get_recovery_suggestions(error_type)
    }
    
    # Add fallback response if available
    if context[:service_type] && has_fallback?(context.service_type) do
      fallback = get_fallback_response(context.service_type, context)
      Map.put(response, :fallback_response, fallback)
    else
      response
    end
  end

  defp select_question_for_missing_field(field) do
    case field do
      "business_activities" ->
        "What is your organization's primary business activity or main service?"
      
      "operational_regions" ->
        "In which geographical regions does your organization operate?"
      
      "industry_sector" ->
        "What industry sector does your organization belong to?"
      
      "employee_count" ->
        "Approximately how many employees does your organization have?"
      
      _ ->
        "Could you provide more information about your organization?"
    end
  end

  defp identify_basic_missing_fields(profile) do
    required_fields = ["business_activities", "operational_regions", "industry_sector", "employee_count"]
    
    Enum.filter(required_fields, fn field ->
      case Map.get(profile, field) do
        nil -> true
        "" -> true
        [] -> true
        _ -> false
      end
    end)
  end

  defp attempt_basic_extraction(response) do
    # Very basic keyword-based extraction as fallback
    response_lower = String.downcase(response)
    
    extracted = %{}
    
    # Extract potential numbers (employee count)
    extracted = if Regex.match?(~r/\d+/, response) do
      Map.put(extracted, "employee_count", extract_first_number(response))
    else
      extracted
    end
    
    # Extract potential regions
    uk_regions = ["england", "scotland", "wales", "northern ireland", "uk", "britain"]
    found_regions = Enum.filter(uk_regions, &String.contains?(response_lower, &1))
    
    extracted = if length(found_regions) > 0 do
      Map.put(extracted, "operational_regions", found_regions)
    else
      extracted
    end
    
    %{
      extracted_fields: extracted,
      confidence_scores: Map.new(extracted, fn {k, _} -> {k, 0.3} end),
      fallback_used: true
    }
  end

  defp extract_first_number(text) do
    case Regex.run(~r/(\d+)/, text) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  defp format_interruption_reason(error_type, error_details) do
    base_reason = Map.get(@error_types, error_type, "unknown_error")
    
    if error_details do
      "#{base_reason}: #{inspect(error_details)}"
    else
      base_reason
    end
  end

  defp update_service_status(service_name, status, details \\ nil) do
    # Store service health status (could use ETS, GenServer, or database)
    # For now, just log the status change
    Logger.info("Service #{service_name} status: #{status} #{if details, do: "- #{details}", else: ""}")
    
    # In a real implementation, you might:
    # - Store in ETS table for quick access
    # - Publish to Phoenix.PubSub for real-time updates
    # - Store in database for persistence
    # - Send alerts if service becomes unhealthy
  end

  defp has_fallback?(service_type) do
    service_type in [:question_generation, :gap_analysis, :entity_extraction]
  end

  defp get_recovery_suggestions(error_type) do
    case error_type do
      :network_error ->
        ["Check internet connection", "Verify AI service endpoint", "Retry in a few moments"]
      
      :service_timeout ->
        ["Reduce request complexity", "Check service load", "Retry with shorter timeout"]
      
      :api_rate_limit ->
        ["Wait before retrying", "Consider upgrading API plan", "Implement request throttling"]
      
      :authentication_error ->
        ["Verify API credentials", "Check API key validity", "Review service permissions"]
      
      :service_unavailable ->
        ["Check service status page", "Wait for service recovery", "Contact service provider"]
      
      _ ->
        ["Contact system administrator", "Check error logs", "Try again later"]
    end
  end
end