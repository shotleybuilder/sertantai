defmodule SertantaiDocsWeb.Components.CrossRefPreviewTest do
  use SertantaiDocsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias SertantaiDocsWeb.Components.CrossRefPreview

  describe "cross_ref_link/1 component" do
    test "renders basic cross-reference link with preview data" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Sertantai.Accounts.User",
          text: "User Resource",
          url: "/api/ash/Sertantai.Accounts.User",
          valid: true
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(<a href="/api/ash/Sertantai.Accounts.User")
      assert html =~ ~s(class="cross-ref cross-ref-ash")
      assert html =~ ~s(data-ref-type="ash")
      assert html =~ ~s(data-ref-target="Sertantai.Accounts.User")
      assert html =~ ~s(data-preview-enabled="true")
      assert html =~ "User Resource"
    end

    test "renders broken cross-reference link with error styling" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Missing.Resource",
          text: "Missing Resource",
          url: nil,
          valid: false,
          error: "Resource not found"
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(class="cross-ref cross-ref-ash cross-ref-broken")
      assert html =~ ~s(data-error="Resource not found")
      assert html =~ ~s(title="Resource not found")
      refute html =~ ~s(href=)
    end

    test "renders different link types with appropriate styling" do
      test_cases = [
        %{type: :ash, class: "cross-ref-ash"},
        %{type: :exdoc, class: "cross-ref-exdoc"},
        %{type: :dev, class: "cross-ref-internal"},
        %{type: :user, class: "cross-ref-internal"}
      ]

      for test_case <- test_cases do
        assigns = %{
          cross_ref: %{
            type: test_case.type,
            target: "Test.Target",
            text: "Test Link",
            url: "/test",
            valid: true
          }
        }

        html = rendered_to_string(~H"""
        <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} />
        """)

        assert html =~ test_case.class
      end
    end

    test "includes accessibility attributes" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Sertantai.Accounts.User",
          text: "User Resource",
          url: "/api/ash/Sertantai.Accounts.User",
          valid: true
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(role="button")
      assert html =~ ~s(aria-describedby="preview-")
      assert html =~ ~s(tabindex="0")
    end

    test "renders custom CSS classes when provided" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Test.Resource",
          text: "Test",
          url: "/test",
          valid: true
        },
        class: "custom-class"
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} class={@class} />
      """)

      assert html =~ ~s(class="cross-ref cross-ref-ash custom-class")
    end
  end

  describe "preview_tooltip/1 component" do
    test "renders ash resource preview with complete information" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Sertantai.Accounts.User",
          preview_data: %{
            resource_type: "ash_resource",
            domain: "Sertantai.Accounts",
            description: "User account resource with authentication",
            actions: ["create", "read", "update", "destroy", "sign_in"],
            attributes: ["email", "name", "role"],
            relationships: ["user_identities", "organizations"]
          }
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(<div class="cross-ref-preview cross-ref-preview-ash")
      assert html =~ "Ash Resource"
      assert html =~ "Sertantai.Accounts"
      assert html =~ "User account resource with authentication"
      assert html =~ "create"
      assert html =~ "email"
      assert html =~ "user_identities"
    end

    test "renders exdoc module preview with documentation" do
      assigns = %{
        cross_ref: %{
          type: :exdoc,
          target: "Enum",
          preview_data: %{
            module_type: "elixir_module",
            description: "Functions for working with collections",
            functions: ["map/2", "filter/2", "reduce/3"],
            examples: ["Enum.map([1, 2, 3], &(&1 * 2))"],
            since: "1.0.0"
          }
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(<div class="cross-ref-preview cross-ref-preview-exdoc")
      assert html =~ "Elixir Module"
      assert html =~ "Functions for working with collections"
      assert html =~ "map/2"
      assert html =~ "Enum.map([1, 2, 3]"
    end

    test "renders internal documentation preview" do
      assigns = %{
        cross_ref: %{
          type: :dev,
          target: "setup-guide",
          preview_data: %{
            title: "Development Setup Guide",
            description: "Complete guide for setting up the development environment",
            category: "Development",
            tags: ["setup", "development", "guide"],
            last_modified: "2024-01-15",
            sections: ["Prerequisites", "Installation", "Configuration"]
          }
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(<div class="cross-ref-preview cross-ref-preview-internal")
      assert html =~ "Documentation"
      assert html =~ "Development Setup Guide"
      assert html =~ "Complete guide for setting up"
      assert html =~ "Prerequisites"
      assert html =~ "setup"
    end

    test "renders error preview for broken links" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Missing.Resource",
          valid: false,
          error: "Resource not found",
          suggestions: ["Existing.Resource", "Another.Resource"]
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      assert html =~ ~s(<div class="cross-ref-preview cross-ref-preview-error")
      assert html =~ "Reference Error"
      assert html =~ "Resource not found"
      assert html =~ "Did you mean:"
      assert html =~ "Existing.Resource"
      assert html =~ "Another.Resource"
    end

    test "handles missing preview data gracefully" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Test.Resource",
          preview_data: nil
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      assert html =~ "Loading preview..."
      assert html =~ ~s(data-loading="true")
    end
  end

  describe "JavaScript integration" do
    test "includes required JavaScript for hover behavior" do
      html = CrossRefPreview.preview_javascript()

      assert html =~ "cross-ref-preview-system"
      assert html =~ "addEventListener('mouseenter'"
      assert html =~ "addEventListener('mouseleave'"
      assert html =~ "addEventListener('focus'"
      assert html =~ "showPreview"
      assert html =~ "hidePreview"
    end

    test "handles keyboard navigation" do
      html = CrossRefPreview.preview_javascript()

      assert html =~ "addEventListener('keydown'"
      assert html =~ "event.key === 'Escape'"
      assert html =~ "event.key === 'Enter'"
      assert html =~ "event.key === ' '"  # Space key
    end

    test "includes debouncing for performance" do
      html = CrossRefPreview.preview_javascript()

      assert html =~ "debounceTimeout"
      assert html =~ "clearTimeout"
      assert html =~ "setTimeout"
    end

    test "handles preview positioning" do
      html = CrossRefPreview.preview_javascript()

      assert html =~ "calculatePosition"
      assert html =~ "getBoundingClientRect"
      assert html =~ "window.innerHeight"
      assert html =~ "window.innerWidth"
    end
  end

  describe "LiveView integration" do
    test "updates previews dynamically when cross-reference data changes" do
      {:ok, view, _html} = live(build_conn(), "/test-page")

      # Simulate loading a document with cross-references
      send(view.pid, {:update_cross_refs, [
        %{
          id: "ref1",
          type: :ash,
          target: "Test.Resource",
          text: "Test Resource",
          valid: true,
          preview_data: %{description: "Test description"}
        }
      ]})

      html = render(view)
      assert html =~ ~s(data-ref-target="Test.Resource")
      assert html =~ "Test description"
    end

    test "handles async preview data loading" do
      {:ok, view, _html} = live(build_conn(), "/test-page")

      # Simulate requesting preview data
      send(view.pid, {:load_preview_data, "Test.Resource", :ash})

      # Should trigger async loading
      assert_receive {:preview_data_loaded, "Test.Resource", _data}, 1000
    end

    test "caches preview data to avoid repeated requests" do
      {:ok, view, _html} = live(build_conn(), "/test-page")

      # Load preview data twice for same target
      send(view.pid, {:load_preview_data, "Test.Resource", :ash})
      send(view.pid, {:load_preview_data, "Test.Resource", :ash})

      # Should only receive one response due to caching
      assert_receive {:preview_data_loaded, "Test.Resource", _data}, 1000
      refute_receive {:preview_data_loaded, "Test.Resource", _data}, 100
    end
  end

  describe "CSS styling" do
    test "includes complete CSS for preview system" do
      css = CrossRefPreview.preview_css()

      # Base cross-reference styles
      assert css =~ ".cross-ref"
      assert css =~ ".cross-ref-ash"
      assert css =~ ".cross-ref-exdoc"
      assert css =~ ".cross-ref-internal"
      assert css =~ ".cross-ref-broken"

      # Preview tooltip styles
      assert css =~ ".cross-ref-preview"
      assert css =~ "position: absolute"
      assert css =~ "z-index:"
      assert css =~ "background:"
      assert css =~ "border:"
      assert css =~ "border-radius:"

      # Animation styles
      assert css =~ "transition:"
      assert css =~ "opacity:"
      assert css =~ "transform:"

      # Responsive design
      assert css =~ "@media"
      assert css =~ "max-width:"
    end

    test "supports dark mode theming" do
      css = CrossRefPreview.preview_css()

      assert css =~ "@media (prefers-color-scheme: dark)"
      assert css =~ "--preview-bg-dark:"
      assert css =~ "--preview-text-dark:"
      assert css =~ "--preview-border-dark:"
    end

    test "includes accessibility features" do
      css = CrossRefPreview.preview_css()

      assert css =~ "focus-visible:"
      assert css =~ "outline:"
      assert css =~ "@media (prefers-reduced-motion: reduce)"
      assert css =~ "transition: none"
    end
  end

  describe "error handling and edge cases" do
    test "handles very long preview content gracefully" do
      long_description = String.duplicate("This is a very long description. ", 100)
      
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Test.Resource",
          preview_data: %{
            description: long_description,
            resource_type: "ash_resource"
          }
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      # Should truncate or handle long content appropriately
      assert html =~ ~s(class="preview-description truncated")
      assert html =~ "Show more"
    end

    test "handles special characters in preview content" do
      assigns = %{
        cross_ref: %{
          type: :exdoc,
          target: "Special.Module",
          preview_data: %{
            description: "Contains <script>alert('xss')</script> and \"quotes\" and 'apostrophes'",
            examples: ["Module.func(\"<dangerous>\")", "& special characters"]
          }
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      # Should escape HTML and handle special characters safely
      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
      assert html =~ "&quot;"
      assert html =~ "&#39;"
    end

    test "handles network errors gracefully" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Test.Resource",
          preview_data: nil,
          loading_error: "Network timeout"
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
      """)

      assert html =~ "Preview unavailable"
      assert html =~ "Network timeout"
      assert html =~ "Retry"
    end

    test "supports high contrast mode" do
      css = CrossRefPreview.preview_css()

      assert css =~ "@media (prefers-contrast: high)"
      assert css =~ "border-width: 2px"
      assert css =~ "font-weight: bold"
    end
  end

  describe "performance optimization" do
    test "lazy loads preview data only when needed" do
      assigns = %{
        cross_ref: %{
          type: :ash,
          target: "Test.Resource",
          text: "Test Resource",
          url: "/test",
          valid: true,
          preview_data: nil  # Not loaded initially
        }
      }

      html = rendered_to_string(~H"""
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} />
      """)

      # Should include data attributes for lazy loading
      assert html =~ ~s(data-lazy-preview="true")
      assert html =~ ~s(data-preview-url="/api/preview/ash/Test.Resource")
    end

    test "debounces hover events to avoid excessive requests" do
      javascript = CrossRefPreview.preview_javascript()

      assert javascript =~ "debounceDelay: 150"
      assert javascript =~ "clearTimeout(debounceTimeout)"
      assert javascript =~ "setTimeout(() => {"
    end

    test "caches rendered preview HTML to avoid re-rendering" do
      javascript = CrossRefPreview.preview_javascript()

      assert javascript =~ "previewCache"
      assert javascript =~ "cacheKey ="
      assert javascript =~ "previewCache.get("
      assert javascript =~ "previewCache.set("
    end
  end
end