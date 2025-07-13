defmodule Sertantai.Organizations.OrganizationService do
  @moduledoc """
  Core organization management service for Phase 1.
  Handles organization creation, user associations, and basic screening workflows.
  """
  
  alias Sertantai.Organizations.{Organization, OrganizationUser, OrganizationLocation, ApplicabilityMatcher}
  alias Sertantai.Organizations.SingleLocationAdapter
  require Ash.Query
  import Ash.Expr
  
  @doc """
  Creates an organization with basic screening results.
  This is the main entry point for Phase 1 organization registration.
  """
  def create_organization_with_basic_screening(attrs, user) do
    with {:ok, organization} <- create_organization(attrs, user),
         {:ok, organization_user} <- associate_user_as_owner(organization, user),
         {:ok, primary_location} <- create_primary_location(organization, attrs),
         {:ok, screening_result} <- perform_basic_screening(organization) do
      {:ok, %{
        organization: organization,
        organization_user: organization_user,
        primary_location: primary_location,
        screening: screening_result
      }}
    end
  end

  @doc """
  Creates a new organization with the provided attributes.
  """
  def create_organization(attrs, user) do
    email_domain = extract_domain(user.email)
    
    organization_attrs = %{
      email_domain: email_domain,
      organization_name: attrs[:organization_name] || attrs["organization_name"],
      created_by_user_id: user.id
    }
    
    Ash.create(Organization, organization_attrs, organization_attrs: attrs, domain: Sertantai.Organizations)
  end

  @doc """
  Associates a user with an organization as the owner.
  """
  def associate_user_as_owner(organization, user) do
    Ash.create(OrganizationUser, %{
      organization_id: organization.id,
      user_id: user.id,
      role: :owner,
      permissions: %{
        "can_edit_organization" => true,
        "can_manage_users" => true,
        "can_view_screening" => true,
        "can_run_screening" => true
      }
    }, domain: Sertantai.Organizations)
  end

  @doc """
  Creates a primary location for a new organization based on the organization attributes.
  This ensures every organization has at least one location for multi-location compatibility.
  """
  def create_primary_location(organization, org_attrs) do
    SingleLocationAdapter.create_primary_location_from_profile(organization)
  end

  @doc """
  Associates a user with an organization with the specified role.
  """
  def associate_user_with_organization(organization, user, role \\ :member) do
    permissions = get_default_permissions_for_role(role)
    
    Ash.create(OrganizationUser, %{
      organization_id: organization.id,
      user_id: user.id,
      role: role,
      permissions: permissions
    }, domain: Sertantai.Organizations)
  end

  @doc """
  Finds or creates an organization for a user based on their email domain.
  """
  def find_or_create_organization_for_user(user) do
    email_domain = extract_domain(user.email)
    
    case find_organization_by_domain(email_domain) do
      {:ok, organization} -> 
        # Check if user is already associated
        case get_user_organization_association(user.id, organization.id) do
          {:ok, _association} -> {:ok, organization}
          {:error, :not_found} -> 
            # Add user to existing organization
            case associate_user_with_organization(organization, user, :member) do
              {:ok, _association} -> {:ok, organization}
              error -> error
            end
        end
        
      {:error, :not_found} ->
        # This means it's a consumer email domain or first user from company
        {:error, :no_organization_found}
    end
  end

  @doc """
  Performs basic applicability screening for an organization.
  """
  def perform_basic_screening(organization) do
    screening_result = ApplicabilityMatcher.perform_basic_screening(organization)
    {:ok, screening_result}
  end

  @doc """
  Updates an organization's profile and recalculates screening if needed.
  """
  def update_organization_profile(organization, attrs) do
    Ash.update(organization, %{}, organization_attrs: attrs, domain: Sertantai.Organizations)
  end

  @doc """
  Gets an organization by ID with error handling.
  """
  def get_organization(id) do
    case Ash.get(Organization, id, domain: Sertantai.Organizations) do
      {:ok, organization} -> {:ok, organization}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Gets organizations associated with a user.
  """
  def get_user_organizations(_user_id) do
    # This would need to be implemented with proper Ash query
    # For now, return empty list
    {:ok, []}
  end

  # Private helper functions

  defp extract_domain(email) do
    email 
    |> String.split("@") 
    |> List.last() 
    |> String.downcase()
  end

  defp find_organization_by_domain(domain) do
    # Skip consumer email domains
    if is_company_domain?(domain) do
      case Ash.read(Organization |> Ash.Query.filter(expr(email_domain == ^domain)), domain: Sertantai.Organizations) do
        {:ok, [organization]} -> {:ok, organization}
        {:ok, []} -> {:error, :not_found}
        error -> error
      end
    else
      {:error, :not_found}
    end
  end

  defp is_company_domain?(domain) do
    consumer_domains = [
      "gmail.com", "hotmail.com", "outlook.com", "yahoo.com", 
      "aol.com", "icloud.com", "live.com", "msn.com", "protonmail.com",
      "yandex.com", "mail.com", "zoho.com"
    ]
    
    domain not in consumer_domains
  end

  defp get_user_organization_association(user_id, organization_id) do
    case Ash.read(OrganizationUser |> Ash.Query.filter(expr(user_id == ^user_id and organization_id == ^organization_id)), domain: Sertantai.Organizations) do
      {:ok, [association]} -> {:ok, association}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  defp get_default_permissions_for_role(:owner) do
    %{
      "can_edit_organization" => true,
      "can_manage_users" => true,
      "can_view_screening" => true,
      "can_run_screening" => true,
      "can_delete_organization" => true
    }
  end

  defp get_default_permissions_for_role(:admin) do
    %{
      "can_edit_organization" => true,
      "can_manage_users" => true,
      "can_view_screening" => true,
      "can_run_screening" => true,
      "can_delete_organization" => false
    }
  end

  defp get_default_permissions_for_role(:member) do
    %{
      "can_edit_organization" => false,
      "can_manage_users" => false,
      "can_view_screening" => true,
      "can_run_screening" => true,
      "can_delete_organization" => false
    }
  end

  defp get_default_permissions_for_role(:viewer) do
    %{
      "can_edit_organization" => false,
      "can_manage_users" => false,
      "can_view_screening" => true,
      "can_run_screening" => false,
      "can_delete_organization" => false
    }
  end

  @doc """
  Validates organization attributes before creation/update.
  """
  def validate_organization_attrs(attrs) do
    errors = []
    
    errors = if blank?(attrs[:organization_name]), 
      do: [{:organization_name, "is required"} | errors], 
      else: errors
      
    errors = if blank?(attrs[:organization_type]), 
      do: [{:organization_type, "is required"} | errors], 
      else: errors
      
    errors = if blank?(attrs[:headquarters_region]), 
      do: [{:headquarters_region, "is required"} | errors], 
      else: errors
      
    errors = if blank?(attrs[:industry_sector]), 
      do: [{:industry_sector, "is required"} | errors], 
      else: errors

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end