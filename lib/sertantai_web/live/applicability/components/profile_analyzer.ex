defmodule SertantaiWeb.Applicability.Components.ProfileAnalyzer do
  @moduledoc """
  Profile analyzer dashboard component for progressive screening.
  Provides real-time analysis of organization profile completeness and recommendations.
  """
  
  use SertantaiWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Profile Analysis Dashboard</h3>
        <div class="flex items-center space-x-2">
          <div class={get_status_indicator_class(@analysis_status)}>
            <div class="w-2 h-2 rounded-full"></div>
          </div>
          <span class="text-sm text-gray-600"><%= format_analysis_status(@analysis_status) %></span>
        </div>
      </div>

      <!-- Profile Completeness Overview -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div class="bg-blue-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-blue-600">
            <%= get_overall_completeness(@complexity_score) %>%
          </div>
          <div class="text-sm text-blue-600 font-medium">Overall Complete</div>
          <div class="text-xs text-gray-600 mt-1">Profile coverage</div>
        </div>

        <div class="bg-green-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-green-600">
            <%= get_data_quality_score(@complexity_score) %>%
          </div>
          <div class="text-sm text-green-600 font-medium">Data Quality</div>
          <div class="text-xs text-gray-600 mt-1">Field accuracy</div>
        </div>

        <div class="bg-purple-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-purple-600">
            <%= get_screening_readiness(@profile_analysis) %>
          </div>
          <div class="text-sm text-purple-600 font-medium">Readiness Level</div>
          <div class="text-xs text-gray-600 mt-1">Screening capability</div>
        </div>
      </div>

      <!-- Phase Breakdown Analysis -->
      <div class="mb-6">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Phase Completion Breakdown</h4>
        <div class="space-y-3">
          <!-- Phase 1 Fields -->
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class={get_phase_icon_class("phase1", @complexity_score)}>
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
              </div>
              <span class="text-sm font-medium text-gray-700">Phase 1 Core Fields</span>
            </div>
            <div class="flex items-center space-x-2">
              <div class="w-32 bg-gray-200 rounded-full h-2">
                <div class="bg-blue-500 h-2 rounded-full transition-all duration-300" 
                     style={"width: #{get_phase1_completeness(@complexity_score)}%"}></div>
              </div>
              <span class="text-xs text-gray-500 w-12 text-right">
                <%= get_phase1_completeness(@complexity_score) %>%
              </span>
            </div>
          </div>

          <!-- Phase 2 Fields -->
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class={get_phase_icon_class("phase2", @complexity_score)}>
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
              </div>
              <span class="text-sm font-medium text-gray-700">Phase 2 Enhanced Fields</span>
            </div>
            <div class="flex items-center space-x-2">
              <div class="w-32 bg-gray-200 rounded-full h-2">
                <div class="bg-green-500 h-2 rounded-full transition-all duration-300" 
                     style={"width: #{get_phase2_completeness(@complexity_score)}%"}></div>
              </div>
              <span class="text-xs text-gray-500 w-12 text-right">
                <%= get_phase2_completeness(@complexity_score) %>%
              </span>
            </div>
          </div>

          <!-- Data Validation -->
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class={get_phase_icon_class("validation", @complexity_score)}>
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
                </svg>
              </div>
              <span class="text-sm font-medium text-gray-700">Data Validation</span>
            </div>
            <div class="flex items-center space-x-2">
              <div class="w-32 bg-gray-200 rounded-full h-2">
                <div class="bg-purple-500 h-2 rounded-full transition-all duration-300" 
                     style={"width: #{get_data_quality(@complexity_score)}%"}></div>
              </div>
              <span class="text-xs text-gray-500 w-12 text-right">
                <%= get_data_quality(@complexity_score) %>%
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Field Impact Analysis -->
      <%= if @profile_analysis do %>
        <div class="mb-6">
          <h4 class="text-sm font-medium text-gray-700 mb-3">Field Impact Analysis</h4>
          <div class="bg-gray-50 rounded-lg p-4">
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span class="font-medium text-gray-700">High Impact Fields:</span>
                <div class="mt-1 space-y-1">
                  <%= for field <- get_high_impact_fields(@profile_analysis) do %>
                    <div class="flex items-center space-x-2">
                      <div class="w-2 h-2 bg-red-400 rounded-full"></div>
                      <span class="text-gray-600"><%= field %></span>
                    </div>
                  <% end %>
                </div>
              </div>
              <div>
                <span class="font-medium text-gray-700">Recommended Next:</span>
                <div class="mt-1 space-y-1">
                  <%= for field <- get_recommended_fields(@profile_analysis) do %>
                    <div class="flex items-center space-x-2">
                      <div class="w-2 h-2 bg-green-400 rounded-full"></div>
                      <span class="text-gray-600"><%= field %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Progressive Screening Recommendations -->
      <%= if length(@recommendations) > 0 do %>
        <div class="mb-6">
          <h4 class="text-sm font-medium text-gray-700 mb-3">Screening Optimization</h4>
          <div class="space-y-2">
            <%= for {recommendation, index} <- Enum.with_index(@recommendations) do %>
              <div class="flex items-start space-x-3 p-3 bg-yellow-50 rounded-lg border border-yellow-200">
                <div class="flex-shrink-0 w-6 h-6 bg-yellow-100 text-yellow-600 rounded-full flex items-center justify-center text-xs font-medium">
                  <%= index + 1 %>
                </div>
                <div class="flex-1">
                  <div class="text-sm text-gray-700"><%= recommendation %></div>
                  <div class="text-xs text-gray-500 mt-1">
                    Impact: <%= get_recommendation_impact(recommendation) %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Performance Metrics -->
      <%= if @complexity_score do %>
        <div>
          <h4 class="text-sm font-medium text-gray-700 mb-3">Performance Insights</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="bg-gray-50 rounded-lg p-3">
              <div class="text-sm font-medium text-gray-700">Query Complexity</div>
              <div class="text-lg font-semibold text-gray-900 capitalize">
                <%= get_recommended_complexity(@complexity_score) %>
              </div>
              <div class="text-xs text-gray-600 mt-1">
                Estimated response: <%= get_estimated_response_time(@complexity_score) %>
              </div>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <div class="text-sm font-medium text-gray-700">Cache Efficiency</div>
              <div class="text-lg font-semibold text-gray-900">
                <%= get_cache_efficiency(@complexity_score) %>%
              </div>
              <div class="text-xs text-gray-600 mt-1">
                Expected hit rate
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for dashboard data processing

  defp get_status_indicator_class(:analyzing), do: "animate-pulse bg-yellow-100 text-yellow-600 px-2 py-1 rounded-full flex items-center"
  defp get_status_indicator_class(:complete), do: "bg-green-100 text-green-600 px-2 py-1 rounded-full flex items-center"
  defp get_status_indicator_class(:insufficient), do: "bg-red-100 text-red-600 px-2 py-1 rounded-full flex items-center"
  defp get_status_indicator_class(_), do: "bg-gray-100 text-gray-600 px-2 py-1 rounded-full flex items-center"

  defp format_analysis_status(:analyzing), do: "Analyzing"
  defp format_analysis_status(:complete), do: "Analysis Complete"
  defp format_analysis_status(:insufficient), do: "Insufficient Data"
  defp format_analysis_status(_), do: "Ready"

  defp get_overall_completeness(%{total_score: score}), do: round(score * 100)
  defp get_overall_completeness(_), do: 0

  defp get_data_quality_score(%{data_quality: quality}), do: round(quality * 100)
  defp get_data_quality_score(_), do: 0

  defp get_screening_readiness(%{screening_readiness: %{recommended_level: level}}), do: String.capitalize(to_string(level))
  defp get_screening_readiness(_), do: "Unknown"

  defp get_phase_icon_class("phase1", %{phase1_completeness: score}) when score >= 0.8, do: "w-6 h-6 text-green-600"
  defp get_phase_icon_class("phase1", %{phase1_completeness: score}) when score >= 0.5, do: "w-6 h-6 text-yellow-600"
  defp get_phase_icon_class("phase1", _), do: "w-6 h-6 text-gray-400"

  defp get_phase_icon_class("phase2", %{phase2_completeness: score}) when score >= 0.8, do: "w-6 h-6 text-green-600"
  defp get_phase_icon_class("phase2", %{phase2_completeness: score}) when score >= 0.5, do: "w-6 h-6 text-yellow-600"
  defp get_phase_icon_class("phase2", _), do: "w-6 h-6 text-gray-400"

  defp get_phase_icon_class("validation", %{data_quality: quality}) when quality >= 0.8, do: "w-6 h-6 text-green-600"
  defp get_phase_icon_class("validation", %{data_quality: quality}) when quality >= 0.5, do: "w-6 h-6 text-yellow-600"
  defp get_phase_icon_class("validation", _), do: "w-6 h-6 text-gray-400"

  defp get_phase_icon_class(_, _), do: "w-6 h-6 text-gray-400"

  defp get_phase1_completeness(%{phase1_completeness: score}), do: round(score * 100)
  defp get_phase1_completeness(_), do: 0

  defp get_phase2_completeness(%{phase2_completeness: score}), do: round(score * 100)
  defp get_phase2_completeness(_), do: 0

  defp get_data_quality(%{data_quality: quality}), do: round(quality * 100)
  defp get_data_quality(_), do: 0

  defp get_high_impact_fields(%{field_analysis: %{high_impact: fields}}), do: fields
  defp get_high_impact_fields(_), do: ["Organization Name", "Industry Sector"]

  defp get_recommended_fields(%{field_analysis: %{recommended_next: fields}}), do: fields
  defp get_recommended_fields(_), do: ["Organization Type", "Headquarters Region"]

  defp get_recommendation_impact(recommendation) do
    cond do
      String.contains?(recommendation, "Phase 2") -> "High"
      String.contains?(recommendation, "performance") -> "Medium"
      String.contains?(recommendation, "quality") -> "Medium"
      true -> "Low"
    end
  end

  defp get_recommended_complexity(%{recommended_complexity: level}), do: String.capitalize(to_string(level))
  defp get_recommended_complexity(_), do: "Basic"

  defp get_estimated_response_time(%{recommended_complexity: :basic}), do: "<100ms"
  defp get_estimated_response_time(%{recommended_complexity: :enhanced}), do: "<300ms"
  defp get_estimated_response_time(%{recommended_complexity: :comprehensive}), do: "<500ms"
  defp get_estimated_response_time(_), do: "Unknown"

  defp get_cache_efficiency(%{total_score: score}) when score >= 0.8, do: 85
  defp get_cache_efficiency(%{total_score: score}) when score >= 0.5, do: 70
  defp get_cache_efficiency(_), do: 45
end