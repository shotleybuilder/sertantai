defmodule Sertantai.Organizations.OrganizationLocation do
  @moduledoc """
  Represents a specific place of operation for an organization.
  Each location can have different operational characteristics
  affecting regulatory applicability.
  
  Phase 1 of multi-location organization support.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Sertantai.Organizations

  require Ash.Query

  postgres do
    table "organization_locations"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Location identification
    attribute :location_name, :string, allow_nil?: false
    attribute :location_type, :atom do
      constraints one_of: [:headquarters, :branch_office, :warehouse, 
                           :manufacturing_site, :retail_outlet, :project_site, 
                           :temporary_location, :home_office, :other]
      default :branch_office
    end
    
    # Geographic details
    attribute :address, :map, allow_nil?: false  # Full address structure
    attribute :geographic_region, :string, allow_nil?: false  # england, scotland, etc.
    attribute :postcode, :string
    attribute :local_authority, :string
    
    # Operational characteristics
    attribute :operational_profile, :map, default: %{}
    attribute :employee_count, :integer
    attribute :annual_revenue, :decimal  # Location-specific revenue
    attribute :operational_status, :atom do
      constraints one_of: [:active, :inactive, :seasonal, :under_construction, :closing]
      default :active
    end
    
    # Regulatory context
    attribute :industry_activities, {:array, :string}, default: []  # Activities performed at this location
    attribute :environmental_factors, :map, default: %{}  # Emissions, waste, etc.
    attribute :health_safety_profile, :map, default: %{}  # H&S characteristics
    attribute :data_processing_activities, {:array, :string}, default: []  # GDPR context
    
    # Metadata
    attribute :is_primary_location, :boolean, default: false
    attribute :established_date, :date
    attribute :compliance_notes, :string
    
    timestamps()
  end

  relationships do
    belongs_to :organization, Sertantai.Organizations.Organization do
      source_attribute :organization_id
      destination_attribute :id
      allow_nil? false
    end
    
    has_many :applicability_screenings, Sertantai.Organizations.LocationScreening do
      destination_attribute :organization_location_id
    end
  end

  actions do
    defaults [:read]
    
    create :create do
      primary? true
      accept [
        :organization_id, :location_name, :location_type, :address, 
        :geographic_region, :postcode, :local_authority, :operational_profile,
        :employee_count, :annual_revenue, :operational_status, :industry_activities,
        :environmental_factors, :health_safety_profile, :data_processing_activities,
        :is_primary_location, :established_date, :compliance_notes
      ]
    end
    
    update :update do
      primary? true
      require_atomic? false
      accept [
        :location_name, :location_type, :address, :geographic_region, 
        :postcode, :local_authority, :operational_profile, :employee_count, 
        :annual_revenue, :operational_status, :industry_activities,
        :environmental_factors, :health_safety_profile, :data_processing_activities,
        :is_primary_location, :established_date, :compliance_notes
      ]
    end
    
    destroy :destroy do
      primary? true
    end
  end

  validations do
    validate present(:location_name), message: "Location name is required"
    validate present(:geographic_region), message: "Geographic region is required"
    validate present(:address), message: "Address is required"
    
    # Ensure only one primary location per organization
    validate fn changeset, _context ->
      if Ash.Changeset.get_attribute(changeset, :is_primary_location) do
        organization_id = Ash.Changeset.get_attribute(changeset, :organization_id)
        
        case organization_id do
          nil -> :ok
          org_id ->
            # Check if another primary location exists for this organization
            existing_primary = 
              __MODULE__
              |> Ash.Query.filter(organization_id: org_id, is_primary_location: true)
              |> Ash.read!(domain: Sertantai.Organizations)
            
            # Allow if this is an update to the same record
            current_id = Ash.Changeset.get_attribute(changeset, :id)
            
            case existing_primary do
              [] -> :ok
              [existing] when existing.id == current_id -> :ok
              _ -> {:error, "Organization can only have one primary location"}
            end
        end
      else
        :ok
      end
    end
  end

  code_interface do
    domain Sertantai.Organizations
    define :create, args: [:organization_id, :location_name, :geographic_region, :address]
    define :read
    define :update
    define :destroy
  end
end