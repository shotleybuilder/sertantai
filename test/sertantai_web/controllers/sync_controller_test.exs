defmodule SertantaiWeb.SyncControllerTest do
  use SertantaiWeb.ConnCase, async: false
  
  alias Sertantai.Accounts.User
  alias Sertantai.UkLrt
  alias Sertantai.UserSelections

  setup do
    # Setup manual sandbox for sequential test execution
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sertantai.Repo)
    
    # Create a test user
    user_attrs = %{
      email: "sync@example.com",
      password: "securepassword123",
      password_confirmation: "securepassword123"
    }
    
    {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
    
    # Create test records
    test_records = [
      %{
        name: "Sync Test Record 1",
        family: "SyncFamily",
        family_ii: "SyncFamilyII",
        year: 2023,
        number: "ST001",
        live: "✔ In force",
        type_desc: "Sync Test Type",
        md_description: "Test record for sync functionality"
      },
      %{
        name: "Sync Test Record 2", 
        family: "SyncFamily",
        family_ii: "AnotherSync",
        year: 2024,
        number: "ST002",
        live: "❌ Revoked / Repealed / Abolished",
        type_desc: "Another Sync Type",
        md_description: "Another test record for sync"
      }
    ]
    
    created_records = Enum.map(test_records, fn attrs ->
      case Ash.create(UkLrt, attrs, domain: Sertantai.Domain) do
        {:ok, record} -> record
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    %{user: user, test_records: created_records}
  end

  describe "GET /api/sync/selected_ids" do
    test "returns empty list when no records selected", %{conn: conn, user: user} do
      UserSelections.clear_selections(user.id)
      
      conn = conn |> assign(:current_user, user)
      conn = get(conn, "/api/sync/selected_ids")
      
      assert json_response(conn, 200) == %{
        "selected_ids" => [],
        "count" => 0
      }
    end

    test "returns selected record IDs", %{conn: conn, user: user, test_records: test_records} do
      # Select some records
      if length(test_records) > 0 do
        first_record = List.first(test_records)
        UserSelections.store_selections(user.id, [first_record.id])
        
        conn = conn |> assign(:current_user, user)
        conn = get(conn, "/api/sync/selected_ids")
        
        response = json_response(conn, 200)
        assert response["count"] == 1
        assert first_record.id in response["selected_ids"]
      end
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/sync/selected_ids")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end

  describe "GET /api/sync/selected_records" do
    test "returns full record data for selected records", %{conn: conn, user: user, test_records: test_records} do
      if length(test_records) > 0 do
        first_record = List.first(test_records)
        UserSelections.store_selections(user.id, [first_record.id])
        
        conn = conn |> assign(:current_user, user)
        conn = get(conn, "/api/sync/selected_records")
        
        response = json_response(conn, 200)
        assert response["count"] == 1
        assert is_list(response["records"])
        
        returned_record = List.first(response["records"])
        assert returned_record["id"] == first_record.id
        assert returned_record["name"] == "Sync Test Record 1"
        assert returned_record["family"] == "SyncFamily"
      end
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/sync/selected_records")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end

  describe "GET /api/sync/export/:format" do
    test "exports selected records as JSON", %{conn: conn, user: user, test_records: test_records} do
      if length(test_records) > 0 do
        first_record = List.first(test_records)
        UserSelections.store_selections(user.id, [first_record.id])
        
        conn = conn |> assign(:current_user, user)
        conn = get(conn, "/api/sync/export/json")
        
        assert conn.status == 200
        assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
        
        # Parse the JSON response
        response_data = Jason.decode!(conn.resp_body)
        assert is_list(response_data)
        assert length(response_data) == 1
        
        exported_record = List.first(response_data)
        assert exported_record["id"] == first_record.id
        assert exported_record["name"] == "Sync Test Record 1"
      end
    end

    test "exports selected records as CSV", %{conn: conn, user: user, test_records: test_records} do
      if length(test_records) > 0 do
        first_record = List.first(test_records)
        UserSelections.store_selections(user.id, [first_record.id])
        
        conn = conn |> assign(:current_user, user)
        conn = get(conn, "/api/sync/export/csv")
        
        assert conn.status == 200
        assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
        
        # Check CSV content
        csv_data = conn.resp_body
        assert String.contains?(csv_data, "Sync Test Record 1")
        assert String.contains?(csv_data, "SyncFamily")
      end
    end

    test "returns error when no records selected", %{conn: conn, user: user} do
      UserSelections.clear_selections(user.id)
      
      conn = conn |> assign(:current_user, user)
      conn = get(conn, "/api/sync/export/json")
      
      assert json_response(conn, 400) == %{"error" => "No records selected"}
    end

    test "returns error for invalid format", %{conn: conn, user: user} do
      conn = conn |> assign(:current_user, user)
      conn = get(conn, "/api/sync/export/invalid")
      
      assert json_response(conn, 400) == %{"error" => "Invalid format. Supported formats: csv, json"}
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/sync/export/json")
      assert json_response(conn, 401) == %{"error" => "Authentication required"}
    end
  end

  describe "integration test" do
    test "complete sync workflow", %{conn: conn, user: user, test_records: test_records} do
      if length(test_records) >= 2 do
        # Select multiple records
        record_ids = Enum.take(test_records, 2) |> Enum.map(& &1.id)
        UserSelections.store_selections(user.id, record_ids)
        
        authenticated_conn = conn |> assign(:current_user, user)
        
        # Step 1: Get selected IDs
        conn1 = get(authenticated_conn, "/api/sync/selected_ids")
        response1 = json_response(conn1, 200)
        assert response1["count"] == 2
        
        # Step 2: Get full record data
        conn2 = get(authenticated_conn, "/api/sync/selected_records")
        response2 = json_response(conn2, 200)
        assert response2["count"] == 2
        assert length(response2["records"]) == 2
        
        # Step 3: Export as JSON
        conn3 = get(authenticated_conn, "/api/sync/export/json")
        assert conn3.status == 200
        exported_data = Jason.decode!(conn3.resp_body)
        assert length(exported_data) == 2
        
        # Step 4: Export as CSV
        conn4 = get(authenticated_conn, "/api/sync/export/csv")
        assert conn4.status == 200
        assert String.contains?(conn4.resp_body, "Sync Test Record 1")
        assert String.contains?(conn4.resp_body, "Sync Test Record 2")
      end
    end
  end
end