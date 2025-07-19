defmodule SertantaiDocs.Navigation.BuilderTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.Navigation.Builder

  describe "build_navigation/1" do
    test "builds navigation from empty scan result" do
      scan_result = %{categories: %{}, files: []}

      navigation = Builder.build_navigation(scan_result)

      assert navigation == %{
        categories: [],
        root_files: [],
        total_files: 0
      }
    end

    test "builds navigation with root files only" do
      scan_result = %{
        categories: %{},
        files: [
          %{
            title: "Getting Started",
            path: "/getting-started",
            file_path: "getting-started.md",
            category: "root",
            priority: 1,
            tags: []
          },
          %{
            title: "FAQ",
            path: "/faq", 
            file_path: "faq.md",
            category: "root",
            priority: 2,
            tags: []
          }
        ]
      }

      navigation = Builder.build_navigation(scan_result)

      assert navigation.total_files == 2
      assert length(navigation.root_files) == 2
      assert length(navigation.categories) == 0

      # Check files are sorted by priority
      [first, second] = navigation.root_files
      assert first.title == "Getting Started"
      assert second.title == "FAQ"
    end

    test "builds navigation with categories and files" do
      scan_result = %{
        categories: %{
          "dev" => %{
            title: "Developer Documentation",
            path: "/dev",
            files: [
              %{
                title: "API Reference",
                path: "/dev/api",
                file_path: "dev/api.md",
                category: "dev",
                priority: 1,
                tags: ["api"]
              },
              %{
                title: "Setup Guide",
                path: "/dev/setup",
                file_path: "dev/setup.md", 
                category: "dev",
                priority: 2,
                tags: ["setup"]
              }
            ]
          },
          "user" => %{
            title: "User Guide",
            path: "/user",
            files: [
              %{
                title: "Getting Started",
                path: "/user/getting-started",
                file_path: "user/getting-started.md",
                category: "user", 
                priority: 1,
                tags: []
              }
            ]
          }
        },
        files: []
      }

      navigation = Builder.build_navigation(scan_result)

      assert navigation.total_files == 3
      assert length(navigation.categories) == 2
      assert length(navigation.root_files) == 0

      # Check categories are sorted alphabetically
      [dev_cat, user_cat] = navigation.categories
      assert dev_cat.title == "Developer Documentation"
      assert user_cat.title == "User Guide"

      # Check files within categories are sorted by priority
      assert length(dev_cat.files) == 2
      [api, setup] = dev_cat.files
      assert api.title == "API Reference"
      assert setup.title == "Setup Guide"
    end

    test "builds breadcrumbs for nested paths" do
      navigation_item = %{
        title: "Setup Guide",
        path: "/dev/getting-started/setup",
        file_path: "dev/getting-started/setup.md",
        category: "dev"
      }

      breadcrumbs = Builder.build_breadcrumbs(navigation_item)

      expected_breadcrumbs = [
        %{title: "Home", path: "/"},
        %{title: "Developer Documentation", path: "/dev"},
        %{title: "Getting Started", path: "/dev/getting-started"},
        %{title: "Setup Guide", path: "/dev/getting-started/setup"}
      ]

      assert breadcrumbs == expected_breadcrumbs
    end

    test "generates table of contents from markdown content" do
      markdown_content = """
      # Main Title

      Some intro content.

      ## Section 1

      Content here.

      ### Subsection 1.1

      More content.

      ## Section 2

      Final content.

      ### Subsection 2.1

      #### Deep section

      Very nested.
      """

      toc = Builder.generate_toc(markdown_content)

      expected_toc = [
        %{level: 1, title: "Main Title", anchor: "main-title"},
        %{level: 2, title: "Section 1", anchor: "section-1"},
        %{level: 3, title: "Subsection 1.1", anchor: "subsection-1-1"},
        %{level: 2, title: "Section 2", anchor: "section-2"},
        %{level: 3, title: "Subsection 2.1", anchor: "subsection-2-1"},
        %{level: 4, title: "Deep section", anchor: "deep-section"}
      ]

      assert toc == expected_toc
    end

    test "filters navigation by category" do
      navigation = %{
        categories: [
          %{title: "Developer", category: "dev", files: [
            %{title: "Setup", category: "dev"}
          ]},
          %{title: "User Guide", category: "user", files: [
            %{title: "Getting Started", category: "user"}
          ]}
        ],
        root_files: [],
        total_files: 2
      }

      filtered = Builder.filter_by_category(navigation, "dev")

      assert length(filtered.categories) == 1
      assert hd(filtered.categories).title == "Developer"
      assert filtered.total_files == 1
    end

    test "searches navigation by query" do
      navigation = %{
        categories: [
          %{title: "Developer", files: [
            %{title: "API Setup Guide", tags: ["api", "setup"]},
            %{title: "Testing Framework", tags: ["testing"]}
          ]}
        ],
        root_files: [
          %{title: "FAQ", tags: ["help"]}
        ]
      }

      # Search by title
      results = Builder.search_navigation(navigation, "setup")
      assert length(results) == 1
      assert hd(results).title == "API Setup Guide"

      # Search by tag
      results = Builder.search_navigation(navigation, "testing")
      assert length(results) == 1
      assert hd(results).title == "Testing Framework"

      # Search case insensitive
      results = Builder.search_navigation(navigation, "api")
      assert length(results) == 1
    end
  end

  describe "path_helpers" do
    test "generates correct paths from file paths" do
      assert Builder.file_path_to_url_path("index.md") == "/"
      assert Builder.file_path_to_url_path("dev/index.md") == "/dev"
      assert Builder.file_path_to_url_path("dev/setup.md") == "/dev/setup"
      assert Builder.file_path_to_url_path("user/guides/advanced.md") == "/user/guides/advanced"
    end

    test "generates slugs from titles" do
      assert Builder.title_to_slug("Getting Started Guide") == "getting-started-guide"
      assert Builder.title_to_slug("API Reference & Examples") == "api-reference-examples"
      assert Builder.title_to_slug("Setup (Advanced)") == "setup-advanced"
    end
  end
end