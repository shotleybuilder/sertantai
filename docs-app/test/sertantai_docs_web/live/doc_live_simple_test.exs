defmodule SertantaiDocsWeb.DocLiveSimpleTest do
  use SertantaiDocsWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "basic DocLive functionality" do
    test "mounts and renders properly with category/page URL", %{conn: conn} do
      # Test with a page that actually exists
      {:ok, view, html} = live(conn, "/user/navigation-features")
      
      # Should render the page content
      assert html =~ "Navigation Features"
      
      # Should render navigation sidebar with sort controls
      assert has_element?(view, "select[phx-change='change-sort']")
      assert has_element?(view, "button[phx-click='toggle-sort-order']")
    end

    test "handles change-sort event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/user/navigation-features")
      
      # Should have sort dropdown
      assert has_element?(view, "select[phx-change='change-sort']")
      
      # Change sort option
      view
      |> element("select[phx-change='change-sort']")
      |> render_change(%{"value" => "title"})
      
      # Should handle the event without error (no crash)
      # The view should still be alive
      assert render(view) =~ "Navigation Features"
    end

    test "handles toggle-sort-order event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/user/navigation-features")
      
      # Should have sort toggle button
      assert has_element?(view, "button[phx-click='toggle-sort-order']")
      
      # Click sort order toggle
      view
      |> element("button[phx-click='toggle-sort-order']")
      |> render_click()
      
      # Should handle the event without error (no crash)
      # The view should still be alive
      assert render(view) =~ "Navigation Features"
    end
  end
end