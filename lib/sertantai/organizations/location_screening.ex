defmodule Sertantai.Organizations.LocationScreening do
  @moduledoc """
  Stores applicability screening results for a specific organization location.
  Links screening sessions to specific places of operation.
  
  Phase 1 of multi-location organization support.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Sertantai.Organizations

  postgres do
    table "location_screenings"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Screening metadata
    attribute :screening_type, :atom do
      constraints one_of: [:progressive, :ai_conversation, :manual_assessment]
      default :progressive
    end
    attribute :screening_status, :atom do
      constraints one_of: [:in_progress, :completed, :requires_review, :archived]
      default :in_progress
    end
    
    # Results
    attribute :applicable_law_count, :integer, default: 0
    attribute :high_priority_count, :integer, default: 0
    attribute :screening_results, :map, default: %{}
    attribute :compliance_recommendations, {:array, :map}, default: []
    
    # Session tracking
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    attribute :last_activity_at, :utc_datetime
    
    timestamps()
  end

  relationships do
    belongs_to :organization_location, Sertantai.Organizations.OrganizationLocation do
      source_attribute :organization_location_id
      destination_attribute :id
      allow_nil? false
    end
    
    belongs_to :conducted_by, Sertantai.Accounts.User do
      source_attribute :conducted_by_user_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:read]
    
    create :create do
      primary? true
      accept [
        :organization_location_id, :conducted_by_user_id, :screening_type,
        :screening_status, :applicable_law_count, :high_priority_count,
        :screening_results, :compliance_recommendations, :started_at,
        :completed_at, :last_activity_at
      ]
    end
    
    update :update do
      primary? true
      require_atomic? false
      accept [
        :screening_type, :screening_status, :applicable_law_count,
        :high_priority_count, :screening_results, :compliance_recommendations,
        :completed_at, :last_activity_at
      ]
    end
    
    update :complete_screening do
      require_atomic? false
      accept [:applicable_law_count, :high_priority_count, :screening_results, :compliance_recommendations]
      
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:screening_status, :completed)
        |> Ash.Changeset.change_attribute(:completed_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:last_activity_at, DateTime.utc_now())
      end
    end
    
    destroy :destroy do
      primary? true
    end
  end

  validations do
    validate present(:organization_location_id), message: "Organization location is required"
    
    # Validate that completed_at is set when status is completed
    validate fn changeset, _context ->
      status = Ash.Changeset.get_attribute(changeset, :screening_status)
      completed_at = Ash.Changeset.get_attribute(changeset, :completed_at)
      
      case {status, completed_at} do
        {:completed, nil} -> {:error, "Completed screenings must have a completed_at timestamp"}
        _ -> :ok
      end
    end
  end

  code_interface do
    domain Sertantai.Organizations
    define :create, args: [:organization_location_id, :conducted_by_user_id]
    define :read
    define :update
    define :complete_screening
    define :destroy
  end
end