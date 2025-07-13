defmodule SertantaiWeb.Applicability.ProgressiveScreeningLiveTest do
  use SertantaiWeb.ConnCase
  import Phoenix.LiveViewTest

  @endpoint SertantaiWeb.Endpoint

  describe "Progressive Screening LiveView" do
    test "mounts and displays initial form", %{conn: conn} do
      {:ok, view, html} = live(conn, "/applicability/progressive")

      assert html =~ "Progressive Applicability Screening"
      assert html =~ "Basic Information"
      assert html =~ "Organization Name"
      assert html =~ "Organization Type"
    end

    test "validates step progression requirements", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Initially on step 1, next button should be disabled
      assert has_element?(view, "button[disabled]", "Next")

      # Fill required fields for step 1
      view
      |> form("#progressive-form", %{
        "field" => "organization_name",
        "value" => "Test Corporation"
      })
      |> render_change()

      view
      |> form("#progressive-form", %{
        "field" => "organization_type", 
        "value" => "limited_company"
      })
      |> render_change()

      # Now next button should be enabled
      refute has_element?(view, "button[disabled]", "Next")
    end

    test "handles real-time field updates with debouncing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Simulate rapid typing - should debounce updates
      start_time = System.monotonic_time(:millisecond)

      view
      |> element("#organization_name")
      |> render_hook("update_field", %{"field" => "organization_name", "value" => "T"})

      view
      |> element("#organization_name") 
      |> render_hook("update_field", %{"field" => "organization_name", "value" => "Te"})

      view
      |> element("#organization_name")
      |> render_hook("update_field", %{"field" => "organization_name", "value" => "Test"})

      # Should handle multiple rapid updates without errors
      assert render(view) =~ "Test"

      update_time = System.monotonic_time(:millisecond) - start_time
      # Updates should be handled efficiently
      assert update_time < 1000
    end

    test "updates progress percentage as profile completes", %{conn: conn} do
      {:ok, view, html} = live(conn, "/applicability/progressive")

      # Initially should show 0% progress
      assert html =~ "0% Complete"

      # Add organization name
      view
      |> element("#organization_name")
      |> render_hook("update_field", %{"field" => "organization_name", "value" => "Test Corp"})

      # Add organization type
      view
      |> element("#organization_type")
      |> render_hook("update_field", %{"field" => "organization_type", "value" => "limited_company"})

      # Progress should increase
      html = render(view)
      refute html =~ "0% Complete"
    end

    test "enables Phase 2 fields when reaching step 3", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Complete step 1
      complete_step_1(view)
      view |> element("button", "Next") |> render_click()

      # Complete step 2
      complete_step_2(view)
      view |> element("button", "Next") |> render_click()

      # Now on step 3 - Phase 2 fields should be available
      html = render(view)
      assert html =~ "Enhanced Profile (Phase 2)"
      assert html =~ "operational_regions"
    end

    test "displays live analysis panel when profile data available", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Complete basic profile
      complete_basic_profile(view)

      # Wait for analysis (debounce period)
      :timer.sleep(1000)

      html = render(view)
      # Should show analysis panel
      assert html =~ "Live Analysis" || html =~ "Profile Analysis"
    end

    test "handles progressive screening execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Complete profile to step 4
      complete_full_profile(view)

      # Navigate to final step
      view |> element("button", "Next") |> render_click()
      view |> element("button", "Next") |> render_click()
      view |> element("button", "Next") |> render_click()

      # Should show start screening button
      assert has_element?(view, "button", "Start Screening")

      # Click start screening
      view |> element("button", "Start Screening") |> render_click()

      # Should show loading state
      html = render(view)
      assert html =~ "Screening..." || html =~ "Progressive screening"
    end

    test "handles form reset functionality", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Fill some data
      view
      |> element("#organization_name")
      |> render_hook("update_field", %{"field" => "organization_name", "value" => "Test Corp"})

      # Reset form
      view |> element("button", "Reset") |> render_click()

      # Form should be cleared
      html = render(view)
      assert html =~ "value=\"\""
    end

    test "validates error handling for invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Enter invalid data
      view
      |> element("#organization_name")
      |> render_hook("update_field", %{"field" => "organization_name", "value" => ""})

      view
      |> element("#organization_type")
      |> render_hook("update_field", %{"field" => "organization_type", "value" => "invalid_type"})

      # Should handle gracefully without crashing
      html = render(view)
      assert html =~ "Progressive Applicability Screening"
    end

    test "maintains step navigation state correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Complete step 1 and navigate forward
      complete_step_1(view)
      view |> element("button", "Next") |> render_click()

      assert has_element?(view, "span", "2")  # Should be on step 2

      # Navigate backward
      view |> element("button", "Previous") |> render_click()

      assert has_element?(view, "span", "1")  # Should be back on step 1
    end

    test "displays component live components correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Complete basic profile to trigger analysis
      complete_basic_profile(view)

      # Wait for analysis processing
      :timer.sleep(1000)

      html = render(view)

      # Should contain profile analyzer component elements
      assert html =~ "Profile Analysis" || html =~ "profile-analyzer"
    end
  end

  describe "Real-time streaming and PubSub" do
    test "subscribes to applicability results on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Should be subscribed to PubSub topic
      assert_receive {:phoenix, :live_view, _view_pid, _event}, 5000
    end

    test "handles streaming events gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Simulate streaming event
      send(view.pid, {:applicability_stream_event, :phase_started, %{phase: :basic}})

      # Should handle event without crashing
      html = render(view)
      assert html =~ "Progressive Applicability Screening"
    end

    test "processes profile analysis notifications", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Simulate profile change notification
      send(view.pid, {:profile_change_notification, %{recommendation: "Test recommendation"}})

      # Should handle notification gracefully
      html = render(view)
      assert html =~ "Progressive Applicability Screening"
    end
  end

  describe "Performance and responsiveness" do
    test "handles rapid form updates efficiently", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      start_time = System.monotonic_time(:millisecond)

      # Simulate rapid form updates
      for i <- 1..10 do
        view
        |> element("#organization_name")
        |> render_hook("update_field", %{"field" => "organization_name", "value" => "Test#{i}"})
      end

      execution_time = System.monotonic_time(:millisecond) - start_time

      # Should handle rapid updates within reasonable time
      assert execution_time < 2000
    end

    test "maintains responsiveness during analysis", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/applicability/progressive")

      # Trigger analysis with complete profile
      complete_basic_profile(view)

      # Should remain responsive during analysis
      start_time = System.monotonic_time(:millisecond)
      html = render(view)
      render_time = System.monotonic_time(:millisecond) - start_time

      assert html =~ "Progressive Applicability Screening"
      assert render_time < 1000  # Should render quickly
    end
  end

  # Helper functions for test setup

  defp complete_step_1(view) do
    view
    |> element("#organization_name")
    |> render_hook("update_field", %{"field" => "organization_name", "value" => "Test Corporation"})

    view
    |> element("#organization_type")
    |> render_hook("update_field", %{"field" => "organization_type", "value" => "limited_company"})
  end

  defp complete_step_2(view) do
    view
    |> element("#headquarters_region")
    |> render_hook("update_field", %{"field" => "headquarters_region", "value" => "england"})

    view
    |> element("#industry_sector")
    |> render_hook("update_field", %{"field" => "industry_sector", "value" => "construction"})
  end

  defp complete_basic_profile(view) do
    complete_step_1(view)
    complete_step_2(view)
  end

  defp complete_full_profile(view) do
    complete_basic_profile(view)

    # Add Phase 2 fields
    view
    |> element("#total_employees")
    |> render_hook("update_field", %{"field" => "total_employees", "value" => "100"})

    view
    |> element("#annual_turnover")
    |> render_hook("update_field", %{"field" => "annual_turnover", "value" => "5000000"})
  end
end