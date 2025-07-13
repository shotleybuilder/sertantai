defmodule Sertantai.Organizations.LocationScreeningTest do
  use Sertantai.DataCase, async: false
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation, LocationScreening}
  alias Sertantai.Accounts.User
  
  describe "location_screening creation" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "screening_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Screening Test Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create a test location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Main St", "city" => "Manchester"},
        geographic_region: "england",
        employee_count: 25
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization, location: location}
    end

    test "creates screening with valid attributes", %{location: location, user: user} do
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive,
        screening_status: :in_progress,
        applicable_law_count: 45,
        high_priority_count: 8,
        started_at: DateTime.utc_now()
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      assert screening.screening_type == :progressive
      assert screening.screening_status == :in_progress
      assert screening.applicable_law_count == 45
      assert screening.high_priority_count == 8
    end
    
    test "requires organization_location_id", %{user: user} do
      attrs = %{
        conducted_by_user_id: user.id,
        screening_type: :progressive,
        screening_status: :in_progress
      }
      
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
    end
    
    test "uses default values correctly", %{location: location} do
      attrs = %{
        organization_location_id: location.id
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      assert screening.screening_type == :progressive  # default value
      assert screening.screening_status == :in_progress  # default value
      assert screening.applicable_law_count == 0  # default value
      assert screening.high_priority_count == 0  # default value
      assert screening.screening_results == %{}  # default value
      assert screening.compliance_recommendations == []  # default value
    end
    
    test "validates screening_type enum values", %{location: location} do
      # Valid screening types
      for type <- [:progressive, :ai_conversation, :manual_assessment] do
        attrs = %{
          organization_location_id: location.id,
          screening_type: type
        }
        assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
        assert screening.screening_type == type
      end
    end
    
    test "validates screening_status enum values", %{location: location} do
      # Valid screening statuses
      for status <- [:in_progress, :completed, :requires_review, :archived] do
        attrs = %{
          organization_location_id: location.id,
          screening_status: status
        }
        assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
        assert screening.screening_status == status
      end
    end
    
    test "stores complex screening results", %{location: location, user: user} do
      screening_results = %{
        "geographic_laws" => 15,
        "activity_laws" => 20,
        "size_laws" => 8,
        "environmental_laws" => 5,
        "data_protection_laws" => 3,
        "employment_laws" => 12,
        "safety_laws" => 7
      }
      
      recommendations = [
        %{
          "priority" => "high",
          "category" => "employment",
          "message" => "Review employment contracts for compliance with Working Time Regulations",
          "law_references" => ["WTR1998", "ERA1996"]
        },
        %{
          "priority" => "medium",
          "category" => "safety",
          "message" => "Update safety procedures for construction activities",
          "law_references" => ["HSW1974", "CDM2015"]
        }
      ]
      
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive,
        screening_status: :completed,
        applicable_law_count: 70,
        high_priority_count: 12,
        screening_results: screening_results,
        compliance_recommendations: recommendations,
        started_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
        completed_at: DateTime.utc_now(),
        last_activity_at: DateTime.utc_now()
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      assert screening.screening_results["geographic_laws"] == 15
      assert screening.screening_results["activity_laws"] == 20
      assert length(screening.compliance_recommendations) == 2
      assert hd(screening.compliance_recommendations)["priority"] == "high"
      assert hd(screening.compliance_recommendations)["category"] == "employment"
    end
    
    test "tracks session timing correctly", %{location: location, user: user} do
      now = DateTime.utc_now()
      started = DateTime.add(now, -1800, :second)  # 30 minutes ago
      completed = now
      
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_status: :completed,
        started_at: started,
        completed_at: completed,
        last_activity_at: completed
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      assert DateTime.compare(screening.started_at, screening.completed_at) == :lt
      assert DateTime.compare(screening.completed_at, screening.last_activity_at) == :eq
    end
    
    test "allows multiple screenings per location", %{location: location, user: user} do
      # Create first screening
      attrs1 = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive,
        screening_status: :completed,
        started_at: DateTime.utc_now() |> DateTime.add(-7200, :second)
      }
      assert {:ok, _screening1} = Ash.create(LocationScreening, attrs1, domain: Sertantai.Organizations)
      
      # Create second screening for same location
      attrs2 = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :ai_conversation,
        screening_status: :in_progress,
        started_at: DateTime.utc_now()
      }
      assert {:ok, _screening2} = Ash.create(LocationScreening, attrs2, domain: Sertantai.Organizations)
    end
  end
  
  describe "relationships" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "relationship_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Relationship Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create a test location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Relationship Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Main St"},
        geographic_region: "england"
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization, location: location}
    end
    
    test "belongs to organization location", %{location: location, user: user} do
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      
      # Load the organization_location relationship
      {:ok, screening_with_location} = Ash.load(screening, [:organization_location], domain: Sertantai.Organizations)
      
      assert screening_with_location.organization_location.id == location.id
      assert screening_with_location.organization_location.location_name == "Relationship Test Location"
    end
    
    test "belongs to conducting user", %{location: location, user: user} do
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      
      # Load the conducted_by relationship
      {:ok, screening_with_user} = Ash.load(screening, [:conducted_by], domain: Sertantai.Organizations)
      
      assert screening_with_user.conducted_by.id == user.id
      assert to_string(screening_with_user.conducted_by.email) == "relationship_test@example.com"
    end
    
    test "location can load its screenings", %{location: location, user: user} do
      # Create multiple screenings for the location
      for i <- 1..3 do
        attrs = %{
          organization_location_id: location.id,
          conducted_by_user_id: user.id,
          screening_type: :progressive,
          screening_status: if(rem(i, 2) == 0, do: :completed, else: :in_progress),
          started_at: DateTime.utc_now() |> DateTime.add(-i * 3600, :second)
        }
        {:ok, _screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      end
      
      # Load screenings relationship
      {:ok, location_with_screenings} = Ash.load(location, [:applicability_screenings], domain: Sertantai.Organizations)
      
      assert length(location_with_screenings.applicability_screenings) == 3
      
      # Check mix of statuses
      statuses = Enum.map(location_with_screenings.applicability_screenings, & &1.screening_status)
      assert :completed in statuses
      assert :in_progress in statuses
    end
    
    test "allows screening without conducting user", %{location: location} do
      attrs = %{
        organization_location_id: location.id,
        screening_type: :manual_assessment,
        screening_status: :requires_review
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      assert screening.conducted_by_user_id == nil
    end
  end
  
  describe "data integrity" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "integrity_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Integrity Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create a test location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Integrity Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Main St"},
        geographic_region: "england"
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization, location: location}
    end
    
    test "screening is deleted when location is deleted", %{location: location, user: user} do
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      screening_id = screening.id
      
      # Delete the location
      :ok = Ash.destroy(location, domain: Sertantai.Organizations)
      
      # Screening should also be deleted (cascade delete)
      assert {:error, _} = Ash.get(LocationScreening, screening_id, domain: Sertantai.Organizations)
    end
    
    test "conducted_by is nullified when user is deleted", %{location: location, user: user} do
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      screening_id = screening.id
      
      # Delete the user
      :ok = Ash.destroy(user, domain: Sertantai.Accounts)
      
      # Screening should still exist but conducted_by_user_id should be null
      {:ok, updated_screening} = Ash.get(LocationScreening, screening_id, domain: Sertantai.Organizations)
      assert updated_screening.conducted_by_user_id == nil
    end
    
    test "cannot create screening with non-existent location" do
      fake_location_id = Ecto.UUID.generate()
      
      attrs = %{
        organization_location_id: fake_location_id,
        screening_type: :progressive
      }
      
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
    end
    
    test "cannot create screening with non-existent user", %{location: location} do
      fake_user_id = Ecto.UUID.generate()
      
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: fake_user_id,
        screening_type: :progressive
      }
      
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
    end
  end
  
  describe "screening workflow" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "workflow_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Workflow Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create a test location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Workflow Test Location",
        location_type: :manufacturing_site,
        address: %{"street" => "123 Industrial Way"},
        geographic_region: "england",
        employee_count: 150,
        industry_activities: ["manufacturing", "assembly", "quality_control"]
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization, location: location}
    end
    
    test "progressive screening workflow", %{location: location, user: user} do
      # Start screening
      start_time = DateTime.utc_now()
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :progressive,
        screening_status: :in_progress,
        started_at: start_time,
        last_activity_at: start_time
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      
      # Update during screening progress
      update_time = DateTime.add(start_time, 1800, :second)  # 30 minutes later
      partial_results = %{
        "step_1_geographic" => %{"laws_found" => 15, "status" => "completed"},
        "step_2_activities" => %{"laws_found" => 22, "status" => "in_progress"}
      }
      
      updated_attrs = %{
        screening_results: partial_results,
        last_activity_at: update_time,
        applicable_law_count: 37
      }
      
      assert {:ok, updated_screening} = Ash.update(screening, updated_attrs, domain: Sertantai.Organizations)
      assert updated_screening.screening_results["step_1_geographic"]["status"] == "completed"
      assert updated_screening.applicable_law_count == 37
      
      # Complete screening
      complete_time = DateTime.add(start_time, 3600, :second)  # 1 hour later
      final_results = %{
        "step_1_geographic" => %{"laws_found" => 15, "status" => "completed"},
        "step_2_activities" => %{"laws_found" => 22, "status" => "completed"},
        "step_3_size_scope" => %{"laws_found" => 8, "status" => "completed"},
        "step_4_environmental" => %{"laws_found" => 5, "status" => "completed"}
      }
      
      final_recommendations = [
        %{
          "priority" => "high",
          "category" => "environmental",
          "message" => "Manufacturing site requires environmental impact assessment",
          "affected_activities" => ["manufacturing", "assembly"]
        }
      ]
      
      completion_attrs = %{
        screening_status: :completed,
        screening_results: final_results,
        compliance_recommendations: final_recommendations,
        applicable_law_count: 50,
        high_priority_count: 9,
        completed_at: complete_time,
        last_activity_at: complete_time
      }
      
      assert {:ok, final_screening} = Ash.update(updated_screening, completion_attrs, domain: Sertantai.Organizations)
      assert final_screening.screening_status == :completed
      assert final_screening.applicable_law_count == 50
      assert final_screening.high_priority_count == 9
      assert length(final_screening.compliance_recommendations) == 1
    end
    
    test "ai conversation screening workflow", %{location: location, user: user} do
      attrs = %{
        organization_location_id: location.id,
        conducted_by_user_id: user.id,
        screening_type: :ai_conversation,
        screening_status: :completed,
        screening_results: %{
          "conversation_turns" => 12,
          "topics_covered" => ["employment", "safety", "environmental", "data_protection"],
          "clarifications_requested" => 3,
          "confidence_score" => 0.87
        },
        compliance_recommendations: [
          %{
            "priority" => "high",
            "category" => "safety",
            "message" => "Manufacturing operations require PUWER compliance assessment",
            "confidence" => 0.92,
            "ai_reasoning" => "Large manufacturing site with 150 employees and assembly operations"
          }
        ],
        applicable_law_count: 48,
        high_priority_count: 7,
        started_at: DateTime.utc_now() |> DateTime.add(-2400, :second),
        completed_at: DateTime.utc_now()
      }
      
      assert {:ok, screening} = Ash.create(LocationScreening, attrs, domain: Sertantai.Organizations)
      assert screening.screening_type == :ai_conversation
      assert screening.screening_results["conversation_turns"] == 12
      assert screening.screening_results["confidence_score"] == 0.87
      assert hd(screening.compliance_recommendations)["ai_reasoning"] != nil
    end
  end
end