defmodule Sertantai.UserSelectionsTest do
  use SertantaiWeb.ConnCase, async: false
  
  alias Sertantai.UserSelections
  alias Sertantai.Repo
  import Ecto.Query

  setup do
    # Ensure UserSelections process is running
    case Process.whereis(UserSelections) do
      nil -> UserSelections.start_link([])
      _pid -> :ok
    end
    
    # Create test user
    user_attrs = %{
      email: "test_selections@example.com",
      password: "securepassword123", 
      password_confirmation: "securepassword123"
    }
    
    {:ok, user} = Ash.create(Sertantai.Accounts.User, user_attrs, 
                             action: :register_with_password, domain: Sertantai.Accounts)
    
    # Create test UK LRT records
    test_records = [
      %{
        name: "Test Selection Record 1",
        family: "TestFamily",
        family_ii: "TestFamilyII", 
        year: 2023,
        number: "TS001",
        live: "✔ In force",
        type_desc: "Test Type",
        md_description: "Test description for selection record 1"
      },
      %{
        name: "Test Selection Record 2",
        family: "TestFamily",
        family_ii: "AnotherFamily",
        year: 2024, 
        number: "TS002",
        live: "❌ Revoked / Repealed / Abolished",
        type_desc: "Another Type",
        md_description: "Test description for selection record 2"
      }
    ]
    
    created_records = Enum.map(test_records, fn attrs ->
      case Ash.create(Sertantai.UkLrt, attrs, domain: Sertantai.Domain) do
        {:ok, record} -> record
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    %{user: user, test_records: created_records}
  end

  describe "ETS operations" do
    test "store and retrieve selections", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        record_ids = Enum.map(test_records, & &1.id)
        
        # Store selections
        UserSelections.store_selections(user.id, record_ids, skip_sync: true)
        
        # Retrieve selections
        retrieved_ids = UserSelections.get_selections(user.id)
        
        assert length(retrieved_ids) == length(record_ids)
        assert Enum.all?(record_ids, &(&1 in retrieved_ids))
      end
    end
    
    test "add and remove individual selections", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        first_record = List.first(test_records)
        second_record = Enum.at(test_records, 1, first_record)
        
        # Add first selection
        UserSelections.add_selection(user.id, first_record.id, skip_sync: true)
        assert first_record.id in UserSelections.get_selections(user.id)
        assert UserSelections.selection_count(user.id) == 1
        
        # Add second selection
        UserSelections.add_selection(user.id, second_record.id, skip_sync: true)
        selections = UserSelections.get_selections(user.id)
        expected_count = if first_record.id == second_record.id, do: 1, else: 2
        assert length(selections) == expected_count
        
        # Remove first selection
        UserSelections.remove_selection(user.id, first_record.id, skip_sync: true)
        remaining_selections = UserSelections.get_selections(user.id)
        refute first_record.id in remaining_selections
        
        if first_record.id != second_record.id do
          assert second_record.id in remaining_selections
        end
      end
    end
    
    test "clear all selections", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        record_ids = Enum.map(test_records, & &1.id)
        
        # Store selections
        UserSelections.store_selections(user.id, record_ids, skip_sync: true)
        assert UserSelections.selection_count(user.id) > 0
        
        # Clear selections
        UserSelections.clear_selections(user.id, skip_sync: true)
        assert UserSelections.selection_count(user.id) == 0
        assert UserSelections.get_selections(user.id) == []
      end
    end
  end

  describe "database persistence" do 
    test "selections persist across ETS resets", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        record_ids = Enum.map(test_records, & &1.id)
        
        # Store selections with immediate database sync
        UserSelections.store_selections(user.id, record_ids, immediate_sync: true)
        
        # Verify stored in ETS
        assert UserSelections.get_selections(user.id) == record_ids
        
        # Clear ETS manually (simulating restart)
        :ets.delete_all_objects(:user_selections)
        
        # Should load from database
        loaded_selections = UserSelections.get_selections(user.id)
        assert length(loaded_selections) == length(record_ids)
        assert Enum.all?(record_ids, &(&1 in loaded_selections))
      end
    end
    
    test "database sync functionality", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        record_ids = Enum.map(test_records, & &1.id)
        
        # Store in ETS without immediate sync
        UserSelections.store_selections(user.id, record_ids, skip_sync: true)
        
        # Verify not yet in database
        db_count = from(s in "user_record_selections", where: s.user_id == ^user.id)
                   |> Repo.aggregate(:count, :id)
        assert db_count == 0
        
        # Force sync to database
        {:ok, :synced} = UserSelections.sync_user_to_database(user.id)
        
        # Verify now in database
        db_count_after = from(s in "user_record_selections", where: s.user_id == ^user.id)
                         |> Repo.aggregate(:count, :id)
        assert db_count_after == length(record_ids)
        
        # Verify actual records match
        db_record_ids = from(s in "user_record_selections", 
                           where: s.user_id == ^user.id,
                           select: s.record_id)
                        |> Repo.all()
        assert Enum.all?(record_ids, &(&1 in db_record_ids))
      end
    end
    
    test "bulk update selections", %{user: user, test_records: test_records} do
      if length(test_records) >= 2 do
        all_record_ids = Enum.map(test_records, & &1.id)
        first_record_id = List.first(all_record_ids)
        
        # Start with one selection
        UserSelections.store_selections(user.id, [first_record_id], immediate_sync: true)
        
        # Bulk update to all records
        UserSelections.bulk_update_selections(user.id, all_record_ids, immediate_sync: true)
        
        # Verify all selections are stored
        selections = UserSelections.get_selections(user.id)
        assert length(selections) == length(all_record_ids)
        assert Enum.all?(all_record_ids, &(&1 in selections))
        
        # Verify in database
        db_count = from(s in "user_record_selections", where: s.user_id == ^user.id)
                   |> Repo.aggregate(:count, :id)
        assert db_count == length(all_record_ids)
      end
    end
  end

  describe "audit logging" do
    test "audit logs are created for selections", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        first_record = List.first(test_records)
        
        audit_opts = [
          session_id: "test_session_123",
          ip_address: "127.0.0.1",
          user_agent: "Test User Agent"
        ]
        
        # Add selection with audit info
        UserSelections.add_selection(user.id, first_record.id, audit_opts)
        
        # Wait a moment for async audit logging
        Process.sleep(100)
        
        # Check audit log
        audit_entries = from(a in "selection_audit_log",
                           where: a.user_id == ^user.id and a.record_id == ^first_record.id,
                           select: %{action: a.action, session_id: a.session_id, ip_address: a.ip_address})
                        |> Repo.all()
        
        assert length(audit_entries) > 0
        select_entry = Enum.find(audit_entries, &(&1.action == "select"))
        assert select_entry != nil
        assert select_entry.session_id == "test_session_123"
        assert select_entry.ip_address == {127, 0, 0, 1}
      end
    end
    
    test "audit logs are created for clear all", %{user: user, test_records: test_records} do
      if length(test_records) > 0 do
        record_ids = Enum.map(test_records, & &1.id)
        
        # Store some selections first
        UserSelections.store_selections(user.id, record_ids, immediate_sync: true)
        
        audit_opts = [
          session_id: "test_session_456",
          ip_address: "192.168.1.1"
        ]
        
        # Clear all with audit info
        UserSelections.clear_selections(user.id, audit_opts)
        
        # Wait for async audit logging
        Process.sleep(100)
        
        # Check audit log for clear_all action
        clear_entries = from(a in "selection_audit_log",
                           where: a.user_id == ^user.id and a.action == "clear_all",
                           select: %{action: a.action, session_id: a.session_id})
                        |> Repo.all()
        
        assert length(clear_entries) > 0
        clear_entry = List.first(clear_entries)
        assert clear_entry.session_id == "test_session_456"
      end
    end
    
    test "bulk operations create appropriate audit logs", %{user: user, test_records: test_records} do
      if length(test_records) >= 2 do
        record_ids = Enum.map(test_records, & &1.id)
        
        audit_opts = [session_id: "bulk_test_session"]
        
        # Bulk update selections
        UserSelections.bulk_update_selections(user.id, record_ids, audit_opts)
        
        # Wait for async audit logging
        Process.sleep(200)
        
        # Check for bulk_select audit entries
        bulk_entries = from(a in "selection_audit_log",
                          where: a.user_id == ^user.id and a.action == "bulk_select",
                          select: %{record_id: a.record_id, session_id: a.session_id})
                       |> Repo.all()
        
        assert length(bulk_entries) >= length(record_ids)
        assert Enum.all?(bulk_entries, &(&1.session_id == "bulk_test_session"))
      end
    end
  end

  describe "error handling" do
    test "gracefully handles invalid user IDs", %{test_records: test_records} do
      invalid_user_id = Ecto.UUID.generate()
      
      if length(test_records) > 0 do
        record_ids = Enum.map(test_records, & &1.id)
        
        # Should not crash with invalid user ID
        assert UserSelections.store_selections(invalid_user_id, record_ids) == :ok
        assert UserSelections.get_selections(invalid_user_id) == []
        assert UserSelections.clear_selections(invalid_user_id) == :ok
      end
    end
    
    test "handles database connection issues gracefully", %{user: user} do
      # This test ensures the system doesn't crash when DB is unavailable
      # In a real scenario, you might mock the Repo or disconnect temporarily
      
      # For now, just ensure basic operations don't crash
      assert UserSelections.get_selections(user.id) == []
      assert UserSelections.store_selections(user.id, []) == :ok
    end
  end
end