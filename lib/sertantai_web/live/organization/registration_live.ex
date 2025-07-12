defmodule SertantaiWeb.Organization.RegistrationLive do
  @moduledoc """
  Phoenix LiveView for Phase 1 organization registration and basic applicability screening.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations.{OrganizationService, ApplicabilityMatcher}

  def mount(_params, session, socket) do
    user = get_user_from_session(session)
    
    socket = 
      socket
      |> assign(:user, user)
      |> assign(:step, :basic_info)
      |> assign(:form_data, %{})
      |> assign(:form_errors, [])
      |> assign(:screening_result, nil)
      |> assign(:organization, nil)
      |> assign(:loading, false)
      |> assign(:industry_sectors, ApplicabilityMatcher.get_supported_industry_sectors())
      |> assign(:regions, ApplicabilityMatcher.get_supported_regions())
      |> assign(:organization_types, ApplicabilityMatcher.get_organization_types())
    
    {:ok, socket}
  end

  def handle_event("validate", %{"organization" => params}, socket) do
    # Real-time validation
    errors = validate_organization_params(params)
    
    socket = 
      socket
      |> assign(:form_data, params)
      |> assign(:form_errors, errors)
    
    {:noreply, socket}
  end

  def handle_event("register_organization", %{"organization" => params}, socket) do
    socket = assign(socket, :loading, true)
    
    case OrganizationService.validate_organization_attrs(atomize_keys(params)) do
      :ok ->
        case OrganizationService.create_organization_with_basic_screening(atomize_keys(params), socket.assigns.user) do
          {:ok, %{organization: org, screening: result}} ->
            socket = 
              socket
              |> assign(:step, :results)
              |> assign(:organization, org)
              |> assign(:screening_result, result)
              |> assign(:loading, false)
              |> put_flash(:info, "Organization registered successfully!")
            
            {:noreply, socket}
            
          {:error, changeset} ->
            errors = extract_changeset_errors(changeset)
            socket = 
              socket
              |> assign(:form_errors, errors)
              |> assign(:loading, false)
              |> put_flash(:error, "Failed to register organization")
            
            {:noreply, socket}
        end
        
      {:error, validation_errors} ->
        socket = 
          socket
          |> assign(:form_errors, validation_errors)
          |> assign(:loading, false)
          |> put_flash(:error, "Please correct the errors below")
        
        {:noreply, socket}
    end
  end

  def handle_event("restart", _params, socket) do
    socket = 
      socket
      |> assign(:step, :basic_info)
      |> assign(:form_data, %{})
      |> assign(:form_errors, [])
      |> assign(:screening_result, nil)
      |> assign(:organization, nil)
      |> assign(:loading, false)
    
    {:noreply, socket}
  end

  def handle_event("continue_to_phase2", _params, socket) do
    # For Phase 1, just show a message about future phases
    socket = put_flash(socket, :info, "Phase 2 enhanced screening will be available in future releases")
    {:noreply, socket}
  end

  # Helper functions

  defp get_user_from_session(session) do
    case session["user_token"] do
      nil -> nil
      token ->
        case extract_user_id_from_token(token) do
          {:ok, user_id} ->
            case Ash.get(Sertantai.Accounts.User, user_id, domain: Sertantai.Accounts) do
              {:ok, user} -> user
              _ -> nil
            end
          _ -> nil
        end
    end
  end

  defp extract_user_id_from_token(token) do
    # Extract user ID from token format: "prefix:user?id=user_id"
    case String.split(token, "id=") do
      [_prefix, user_id] -> {:ok, user_id}
      _ -> {:error, "Invalid token format"}
    end
  end

  defp validate_organization_params(params) do
    errors = []
    
    errors = if blank?(params["organization_name"]), 
      do: [{:organization_name, "is required"} | errors], 
      else: errors
      
    errors = if blank?(params["organization_type"]), 
      do: [{:organization_type, "is required"} | errors], 
      else: errors
      
    errors = if blank?(params["headquarters_region"]), 
      do: [{:headquarters_region, "is required"} | errors], 
      else: errors
      
    errors = if blank?(params["industry_sector"]), 
      do: [{:industry_sector, "is required"} | errors], 
      else: errors

    # Validate employee count if provided
    errors = case params["total_employees"] do
      "" -> errors
      nil -> errors
      value ->
        case Integer.parse(value) do
          {num, ""} when num > 0 -> errors
          _ -> [{:total_employees, "must be a positive number"} | errors]
        end
    end

    errors
  end

  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Enum.into(%{})
  end

  defp extract_changeset_errors(changeset) do
    # Convert Ash changeset errors to our format
    case changeset do
      %{errors: errors} when is_list(errors) ->
        Enum.map(errors, fn error ->
          case error do
            {field, message} -> {field, message}
            %{field: field, message: message} -> {field, message}
            _ -> {:general, "An error occurred"}
          end
        end)
      _ -> [{:general, "An error occurred"}]
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false

  defp has_error?(errors, field) do
    Enum.any?(errors, fn {f, _} -> f == field end)
  end

  defp get_error_message(errors, field) do
    case Enum.find(errors, fn {f, _} -> f == field end) do
      {_, message} -> message
      nil -> nil
    end
  end

  defp format_number(nil), do: "0"
  defp format_number(num) when is_integer(num), do: Integer.to_string(num)
  defp format_number(num) when is_float(num), do: Float.to_string(num)
  defp format_number(num), do: to_string(num)
end