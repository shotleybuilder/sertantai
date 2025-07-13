defmodule Sertantai.Organizations.SingleLocationAdapter do
  @moduledoc """
  Adapter layer to provide seamless experience for single-location organizations.
  Simplifies UI and API when organization has only one location.
  """
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  require Ash.Query

  @doc """
  Determines if organization should use single-location or multi-location interface.
  """
  def interface_mode(organization) do
    case organization.locations do
      %Ash.NotLoaded{} -> :locations_not_loaded
      [_single_location] -> :single_location
      locations when is_list(locations) and length(locations) > 1 -> :multi_location
      [] -> :no_locations
      _ -> :single_location  # Default fallback
    end
  end

  @doc """
  Gets the primary location for single-location organizations.
  """
  def get_primary_location(organization) do
    case interface_mode(organization) do
      :single_location ->
        case organization.locations do
          [location] -> {:ok, location}
          _ -> get_marked_primary_location(organization)
        end
      
      :locations_not_loaded ->
        {:error, :locations_not_loaded}
      
      _ -> 
        {:error, :not_single_location}
    end
  end

  @doc """
  Creates location-aware routing decisions.
  Returns tuple of {mode, route} for navigation.
  """
  def get_screening_route(organization) do
    case interface_mode(organization) do
      :single_location ->
        case get_primary_location(organization) do
          {:ok, location} ->
            {:single_location, "/applicability/location/#{location.id}"}
          _ ->
            {:error, "/organizations/locations"}
        end
      
      :multi_location ->
        {:multi_location, "/applicability/organization/aggregate"}
      
      :no_locations ->
        {:no_locations, "/organizations/locations"}
      
      :locations_not_loaded ->
        {:error, "/organizations"}
    end
  end

  @doc """
  Adapts organization profile for backward compatibility.
  Merges organization data with primary location data for legacy systems.
  """
  def get_legacy_profile(organization) do
    case get_primary_location(organization) do
      {:ok, location} ->
        # Merge organization and location data for legacy compatibility
        organization.core_profile
        |> Map.merge(%{
          "headquarters_region" => location.geographic_region,
          "location_type" => to_string(location.location_type),
          "total_employees" => location.employee_count || organization.core_profile["total_employees"],
          "address" => location.address,
          "postcode" => location.postcode,
          "local_authority" => location.local_authority
        })
      
      {:error, _} ->
        organization.core_profile
    end
  end

  @doc """
  Creates a primary location for an organization from core profile data.
  Used during initial setup or migration.
  """
  def create_primary_location_from_profile(organization) do
    profile = organization.core_profile || %{}
    
    location_attrs = %{
      organization_id: organization.id,
      location_name: "Headquarters",
      location_type: :headquarters,
      address: %{
        "region" => profile["headquarters_region"] || "unknown",
        "country" => "UK"
      },
      geographic_region: profile["headquarters_region"] || "unknown",
      operational_profile: %{
        "total_employees" => profile["total_employees"],
        "industry_sector" => profile["industry_sector"],
        "organization_type" => profile["organization_type"],
        "annual_turnover" => profile["annual_turnover"]
      },
      industry_activities: extract_industry_activities(profile),
      is_primary_location: true,
      operational_status: :active,
      employee_count: profile["total_employees"]
    }
    
    Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
  end

  @doc """
  Checks if organization needs migration to location model.
  """
  def needs_location_migration?(organization) do
    case organization.locations do
      %Ash.NotLoaded{} -> :unknown
      [] -> true
      _ -> false
    end
  end

  @doc """
  Updates organization profile when in single-location mode.
  Transparently updates the primary location.
  """
  def update_single_location_profile(organization, profile_updates) do
    case get_primary_location(organization) do
      {:ok, location} ->
        # Extract location-specific updates
        location_updates = extract_location_updates(profile_updates)
        org_updates = extract_organization_updates(profile_updates)
        
        # Update both organization and location
        with {:ok, _updated_org} <- update_organization_profile(organization, org_updates),
             {:ok, _updated_location} <- update_location_profile(location, location_updates) do
          {:ok, organization}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_marked_primary_location(organization) do
    case Enum.find(organization.locations, &(&1.is_primary_location)) do
      nil -> {:error, :no_primary_location}
      location -> {:ok, location}
    end
  end

  defp extract_industry_activities(profile) do
    activities = []
    
    if profile["industry_sector"] do
      activities ++ [profile["industry_sector"]]
    else
      activities
    end
  end

  defp extract_location_updates(profile_updates) do
    location_fields = ~w(
      headquarters_region
      total_employees
      industry_sector
      annual_turnover
      environmental_impact
      health_safety_required
      data_processing_scale
    )
    
    Map.take(profile_updates, location_fields)
  end

  defp extract_organization_updates(profile_updates) do
    org_fields = ~w(
      organization_name
      organization_type
      website
      description
    )
    
    Map.take(profile_updates, org_fields)
  end

  defp update_organization_profile(organization, updates) do
    new_profile = Map.merge(organization.core_profile || %{}, updates)
    
    Ash.update(organization, %{core_profile: new_profile}, 
      action: :update,
      domain: Sertantai.Organizations
    )
  end

  defp update_location_profile(location, updates) do
    location_attrs = %{}
    
    # Map profile fields to location attributes
    location_attrs = 
      if updates["headquarters_region"] do
        Map.put(location_attrs, :geographic_region, updates["headquarters_region"])
      else
        location_attrs
      end
    
    location_attrs = 
      if updates["total_employees"] do
        Map.put(location_attrs, :employee_count, updates["total_employees"])
      else
        location_attrs
      end
    
    # Update operational profile
    if Enum.any?(updates, fn {k, _} -> k in ~w(industry_sector annual_turnover) end) do
      new_op_profile = 
        location.operational_profile
        |> Map.merge(Map.take(updates, ~w(industry_sector annual_turnover)))
      
      location_attrs = Map.put(location_attrs, :operational_profile, new_op_profile)
    end
    
    if map_size(location_attrs) > 0 do
      Ash.update(location, location_attrs,
        action: :update,
        domain: Sertantai.Organizations
      )
    else
      {:ok, location}
    end
  end
end