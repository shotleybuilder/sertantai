defmodule Sertantai.Organizations.Organization do
  @moduledoc """
  Organization resource for Phase 1 applicability screening.
  Stores core organization profile data for basic regulation matching.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Sertantai.Organizations

  postgres do
    table "organizations"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Domain identification
    attribute :email_domain, :string, allow_nil?: false
    attribute :organization_name, :string, allow_nil?: false
    attribute :verified, :boolean, default: false
    
    # Core profile (Phase 1 fields only)
    attribute :core_profile, :map, allow_nil?: false, default: %{}
    
    # Metadata
    attribute :created_by_user_id, :uuid, allow_nil?: false
    attribute :profile_completeness_score, :decimal, default: 0.0
    
    timestamps()
  end

  # Core Profile Fields Structure (Phase 1 + Phase 2):
  # {
  #   # Phase 1 Core Fields
  #   "organization_name": "ACME Construction Ltd",
  #   "organization_type": "limited_company", 
  #   "registration_number": "12345678",
  #   "headquarters_region": "england",
  #   "total_employees": 75,
  #   "primary_sic_code": "41201",
  #   "industry_sector": "construction",
  #   
  #   # Phase 2 Extended Fields for Enhanced Profiling
  #   "operational_regions": ["england", "wales"],
  #   "annual_turnover": 2500000,
  #   "business_activities": ["construction", "civil_engineering", "project_management"],
  #   "compliance_requirements": ["health_safety", "environmental", "data_protection"],
  #   "risk_profile": "medium",
  #   "special_circumstances": "Listed company with overseas operations"
  # }

  relationships do
    belongs_to :created_by, Sertantai.Accounts.User do
      source_attribute :created_by_user_id
      destination_attribute :id
    end
    
    has_many :organization_users, Sertantai.Organizations.OrganizationUser do
      destination_attribute :organization_id
    end
  end

  calculations do
    calculate :profile_completeness_percentage, :decimal, expr(profile_completeness_score * 100) do
      description "Profile completeness as a percentage (0-100)"
    end
    
    # Phase 2 Enhanced Profile Completeness Calculation
    calculate :phase2_completeness_score, :decimal, {Sertantai.Organizations.Calculations.Phase2Completeness, []} do
      description "Phase 2 profile completeness score including extended attributes (0.0-1.0)"
    end
    
    calculate :phase2_completeness_percentage, :decimal, expr(phase2_completeness_score * 100) do
      description "Phase 2 profile completeness as a percentage (0-100)"
    end
  end

  actions do
    defaults [:read]
    
    create :create do
      accept [:email_domain, :organization_name, :core_profile, :created_by_user_id]
      
      argument :organization_attrs, :map do
        description "Organization attributes for core profile"
      end
      
      change fn changeset, _context ->
        case Ash.Changeset.get_argument(changeset, :organization_attrs) do
          nil -> changeset
          attrs -> 
            core_profile = build_core_profile(attrs)
            completeness = calculate_completeness(core_profile)
            
            changeset
            |> Ash.Changeset.change_attribute(:core_profile, core_profile)
            |> Ash.Changeset.change_attribute(:profile_completeness_score, completeness)
        end
      end
    end
    
    update :update do
      accept [:organization_name, :core_profile, :verified]
      require_atomic? false
      
      argument :organization_attrs, :map do
        description "Updated organization attributes"
      end
      
      change fn changeset, _context ->
        case Ash.Changeset.get_argument(changeset, :organization_attrs) do
          nil -> changeset
          attrs ->
            existing_profile = Ash.Changeset.get_attribute(changeset, :core_profile) || %{}
            updated_profile = Map.merge(existing_profile, build_core_profile(attrs))
            completeness = calculate_completeness(updated_profile)
            
            changeset
            |> Ash.Changeset.change_attribute(:core_profile, updated_profile)
            |> Ash.Changeset.change_attribute(:profile_completeness_score, completeness)
        end
      end
    end
  end

  validations do
    validate present(:email_domain), message: "Email domain is required"
    validate present(:organization_name), message: "Organization name is required"
    validate present(:created_by_user_id), message: "Created by user is required"
    
    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :core_profile) do
        profile when is_map(profile) ->
          required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
          missing_fields = Enum.filter(required_fields, &(!Map.has_key?(profile, &1)))
          
          case missing_fields do
            [] -> :ok
            fields -> {:error, "Core profile missing required fields: #{Enum.join(fields, ", ")}"}
          end
        _ -> {:error, "Core profile must be a valid map"}
      end
    end
  end

  code_interface do
    domain Sertantai.Organizations
    define :create, args: [:email_domain, :organization_name, :created_by_user_id]
    define :read
    define :update
  end

  # Helper functions for building core profile
  defp build_core_profile(attrs) do
    %{
      "organization_name" => attrs[:organization_name] || attrs["organization_name"],
      "organization_type" => attrs[:organization_type] || attrs["organization_type"],
      "registration_number" => attrs[:registration_number] || attrs["registration_number"],
      "headquarters_region" => attrs[:headquarters_region] || attrs["headquarters_region"],
      "total_employees" => attrs[:total_employees] || attrs["total_employees"],
      "primary_sic_code" => attrs[:primary_sic_code] || attrs["primary_sic_code"],
      "industry_sector" => attrs[:industry_sector] || attrs["industry_sector"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
  
  defp calculate_completeness(profile) do
    required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    optional_fields = ["registration_number", "total_employees", "primary_sic_code"]
    
    required_count = Enum.count(required_fields, &Map.has_key?(profile, &1))
    optional_count = Enum.count(optional_fields, &Map.has_key?(profile, &1))
    
    total_required = length(required_fields)
    total_optional = length(optional_fields)
    
    (required_count / total_required * 0.7) + (optional_count / total_optional * 0.3)
  end
end