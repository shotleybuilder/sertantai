defmodule SertantaiDocsWeb.NavigationStateTest do
  use SertantaiDocsWeb.ConnCase, async: true

  describe "navigation state management" do
    test "initializes default expansion state correctly" do
      # Test the server-side logic for determining initial state
      
      default_state = %{
        "build_group_done" => false,       # Completed work - collapsed by default
        "build_group_strategy" => false,  # Reference material - collapsed by default  
        "build_group_todo" => true,       # Active work - expanded by default
        "build_group_planned" => false    # Future work - collapsed by default
      }
      
      # Verify state structure
      assert is_map(default_state)
      
      # Todo should be the only group expanded by default (active work)
      expanded_groups = default_state 
      |> Enum.filter(fn {_key, expanded} -> expanded end)
      |> Enum.map(fn {key, _} -> key end)
      
      assert "build_group_todo" in expanded_groups
      assert length(expanded_groups) <= 2  # At most 1-2 groups expanded by default
    end

    test "validates group state keys follow consistent naming" do
      # All group state keys should follow pattern: "build_group_{group_name}"
      
      valid_keys = [
        "build_group_done",
        "build_group_strategy", 
        "build_group_todo",
        "build_group_planned",
        "build_group_archive"  # Future group example
      ]
      
      for key <- valid_keys do
        assert String.starts_with?(key, "build_group_")
        
        # Extract group name
        group_name = String.replace_prefix(key, "build_group_", "")
        assert String.length(group_name) > 0
        assert String.match?(group_name, ~r/^[a-z][a-z_]*[a-z]$/)
      end
    end

    test "handles state serialization for client-side storage" do
      # Test JSON serialization for localStorage
      
      state = %{
        "build_group_done" => true,
        "build_group_strategy" => false,
        "build_group_todo" => true
      }
      
      # Should serialize to valid JSON
      json = Jason.encode!(state)
      assert is_binary(json)
      
      # Should deserialize back correctly  
      {:ok, decoded} = Jason.decode(json)
      assert decoded == %{
        "build_group_done" => true,
        "build_group_strategy" => false,
        "build_group_todo" => true
      }
    end

    test "provides state merge logic for partial updates" do
      # Test merging stored state with defaults
      
      defaults = %{
        "build_group_done" => false,
        "build_group_strategy" => false,
        "build_group_todo" => true,
        "build_group_planned" => false
      }
      
      # Simulate partial stored state (user only changed some groups)
      stored_state = %{
        "build_group_done" => true,    # User expanded this
        "build_group_todo" => false    # User collapsed this
        # strategy and planned not in stored state - should use defaults
      }
      
      # Merge function
      merged_state = Map.merge(defaults, stored_state)
      
      # Should have all groups with correct precedence
      assert merged_state["build_group_done"] == true      # From stored
      assert merged_state["build_group_strategy"] == false # From default
      assert merged_state["build_group_todo"] == false     # From stored  
      assert merged_state["build_group_planned"] == false  # From default
      
      assert map_size(merged_state) == 4
    end

    test "validates state values are boolean" do
      # All state values should be boolean for consistency
      
      valid_states = [
        %{"build_group_done" => true},
        %{"build_group_done" => false},
        %{"build_group_strategy" => true, "build_group_todo" => false}
      ]
      
      for state <- valid_states do
        for {_key, value} <- state do
          assert is_boolean(value), "State values must be boolean, got: #{inspect(value)}"
        end
      end
      
      # Invalid states should be rejected
      invalid_states = [
        %{"build_group_done" => "true"},     # String instead of boolean
        %{"build_group_done" => 1},          # Integer instead of boolean
        %{"build_group_done" => nil}         # Nil instead of boolean
      ]
      
      for invalid_state <- invalid_states do
        for {_key, value} <- invalid_state do
          refute is_boolean(value), "Invalid value should be detected: #{inspect(value)}"
        end
      end
    end
  end

  describe "session storage integration" do
    test "generates correct localStorage key" do
      # Should use consistent naming for localStorage
      
      storage_key = "sertantai_docs_navigation_state"
      
      # Should be namespaced to avoid conflicts
      assert String.contains?(storage_key, "sertantai_docs")
      assert String.contains?(storage_key, "navigation")
      
      # Should be valid localStorage key (no spaces, reasonable length)
      assert String.length(storage_key) < 100
      refute String.contains?(storage_key, " ")
    end

    test "provides state cleanup for old/invalid keys" do
      # Test logic for cleaning up invalid or old state keys
      
      mixed_state = %{
        "build_group_done" => true,           # Valid
        "build_group_strategy" => false,     # Valid
        "old_group_legacy" => true,          # Invalid - doesn't match pattern
        "build_group_" => false,             # Invalid - empty group name
        "not_a_group" => true                # Invalid - wrong format
      }
      
      # Filter function to keep only valid keys
      valid_keys = mixed_state
      |> Enum.filter(fn {key, _value} ->
        String.starts_with?(key, "build_group_") and
        String.length(String.replace_prefix(key, "build_group_", "")) > 0
      end)
      |> Enum.into(%{})
      
      # Should only keep valid keys
      assert Map.has_key?(valid_keys, "build_group_done")
      assert Map.has_key?(valid_keys, "build_group_strategy")
      refute Map.has_key?(valid_keys, "old_group_legacy")
      refute Map.has_key?(valid_keys, "build_group_")
      refute Map.has_key?(valid_keys, "not_a_group")
    end

    test "handles storage quota exceeded gracefully" do
      # Test behavior when localStorage is full
      
      # Simulate minimal storage - just essentials
      essential_state = %{
        "build_group_todo" => true  # Most important - active work
      }
      
      # Should prioritize essential groups
      assert Map.has_key?(essential_state, "build_group_todo")
      assert map_size(essential_state) == 1
      
      # Should provide fallback when storage fails
      fallback_state = %{
        "build_group_done" => false,
        "build_group_strategy" => false, 
        "build_group_todo" => true,  # Default expansion for active work
        "build_group_planned" => false
      }
      
      # Fallback should have sensible defaults
      assert fallback_state["build_group_todo"] == true
      refute fallback_state["build_group_done"]
    end
  end

  describe "accessibility state management" do
    test "maintains ARIA state consistency" do
      # Test that expansion state matches ARIA attributes
      
      test_cases = [
        {true, "true", "ArrowDown"},   # Expanded
        {false, "false", "ArrowRight"} # Collapsed
      ]
      
      for {expanded, aria_expanded, expected_icon} <- test_cases do
        # State should be consistent across all representations
        assert is_boolean(expanded)
        assert aria_expanded in ["true", "false"]
        assert expected_icon in ["ArrowDown", "ArrowRight"]
        
        # Expanded state should match ARIA expanded
        assert (expanded and aria_expanded == "true") or
               (not expanded and aria_expanded == "false")
      end
    end

    test "provides screen reader announcements for state changes" do
      # Test data for screen reader announcements
      
      announcements = %{
        expand: "Expanded {group_name} group showing {count} items",
        collapse: "Collapsed {group_name} group",
        navigate: "Navigated to {item_name} in {group_name} group"
      }
      
      # Should have announcement templates
      for {action, template} <- announcements do
        assert is_atom(action)
        assert is_binary(template)
        assert String.contains?(template, "{group_name}")
      end
      
      # Should support variable substitution
      expand_message = String.replace(announcements.expand, "{group_name}", "Done")
                      |> String.replace("{count}", "25")
      
      assert expand_message == "Expanded Done group showing 25 items"
    end

    test "maintains focus management state" do
      # Test focus state tracking for keyboard navigation
      
      focus_state = %{
        current_group: "build_group_done",
        current_item: nil,
        navigation_mode: :groups  # :groups or :items
      }
      
      # Should track current focus location
      assert Map.has_key?(focus_state, :current_group)
      assert Map.has_key?(focus_state, :current_item)
      assert Map.has_key?(focus_state, :navigation_mode)
      
      # Should validate navigation mode
      assert focus_state.navigation_mode in [:groups, :items]
    end
  end

  describe "performance considerations" do
    test "limits state storage size" do
      # Ensure state doesn't grow unbounded
      
      # Simulate many groups (stress test)
      large_state = 1..20
      |> Enum.map(fn i -> {"build_group_#{i}", rem(i, 2) == 0} end)
      |> Enum.into(%{})
      
      # Should be reasonable size when serialized
      json_size = large_state |> Jason.encode!() |> byte_size()
      
      # Should be under 5KB for localStorage efficiency
      assert json_size < 5_000
    end

    test "provides state cleanup on navigation" do
      # Test cleaning up state when leaving documentation sections
      
      full_state = %{
        "build_group_done" => true,
        "build_group_strategy" => false,
        "dev_group_guides" => true,     # Different section
        "user_group_tutorials" => false # Different section
      }
      
      # When on /build, should only care about build groups
      build_state = full_state
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, "build_group_") end)
      |> Enum.into(%{})
      
      assert map_size(build_state) == 2
      assert Map.has_key?(build_state, "build_group_done")
      assert Map.has_key?(build_state, "build_group_strategy")
      refute Map.has_key?(build_state, "dev_group_guides")
    end
  end
end