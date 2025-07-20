defmodule SertantaiDocs.TOC.ExtractorTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.TOC.Extractor

  describe "extract_headings/1" do
    test "extracts headings from markdown content" do
      content = """
      # Main Title
      
      Some content here.
      
      ## Section One
      
      More content.
      
      ### Subsection 1.1
      
      Details here.
      
      ## Section Two
      
      ### Subsection 2.1
      
      #### Deep Subsection
      
      ### Subsection 2.2
      """
      
      # Force text-based extraction for this test to maintain line number accuracy
      headings = Extractor.extract_headings(content, use_ast: false)
      
      assert length(headings) == 7
      
      assert [
        %{level: 1, text: "Main Title", id: "main-title", line: 1},
        %{level: 2, text: "Section One", id: "section-one", line: 5},
        %{level: 3, text: "Subsection 1.1", id: "subsection-1-1", line: 9},
        %{level: 2, text: "Section Two", id: "section-two", line: 13},
        %{level: 3, text: "Subsection 2.1", id: "subsection-2-1", line: 15},
        %{level: 4, text: "Deep Subsection", id: "deep-subsection", line: 17},
        %{level: 3, text: "Subsection 2.2", id: "subsection-2-2", line: 19}
      ] = headings
    end

    test "handles headings with special characters" do
      content = """
      ## Phoenix.LiveView Components
      ### The `<.form>` Component
      #### Using @myself & Socket Assigns
      """
      
      headings = Extractor.extract_headings(content)
      
      assert [
        %{level: 2, text: "Phoenix.LiveView Components", id: "phoenix-liveview-components"},
        %{level: 3, text: "The <.form> Component", id: "the-form-component"},
        %{level: 4, text: "Using @myself & Socket Assigns", id: "using-myself-socket-assigns"}
      ] = headings
    end

    test "handles headings with inline formatting" do
      content = """
      # Getting Started with **Phoenix**
      ## Using `mix phx.new` Command
      ### The _important_ Configuration
      """
      
      headings = Extractor.extract_headings(content)
      
      assert [
        %{level: 1, text: "Getting Started with Phoenix", id: "getting-started-with-phoenix"},
        %{level: 2, text: "Using mix phx.new Command", id: "using-mix-phx-new-command"},
        %{level: 3, text: "The important Configuration", id: "the-important-configuration"}
      ] = headings
    end

    test "handles duplicate heading text with unique IDs" do
      content = """
      ## Installation
      ### Prerequisites
      ## Configuration
      ### Prerequisites
      """
      
      headings = Extractor.extract_headings(content)
      
      assert [
        %{text: "Installation", id: "installation"},
        %{text: "Prerequisites", id: "prerequisites"},
        %{text: "Configuration", id: "configuration"},
        %{text: "Prerequisites", id: "prerequisites-1"}
      ] = headings
    end

    test "ignores code block content" do
      content = """
      # Real Heading
      
      ```markdown
      # This is not a heading
      ## Neither is this
      ```
      
      ## Another Real Heading
      """
      
      headings = Extractor.extract_headings(content)
      
      assert length(headings) == 2
      assert [
        %{text: "Real Heading"},
        %{text: "Another Real Heading"}
      ] = headings
    end

    test "handles empty content" do
      assert [] = Extractor.extract_headings("")
      assert [] = Extractor.extract_headings(nil)
    end

    test "filters by heading levels" do
      content = """
      # H1
      ## H2
      ### H3
      #### H4
      ##### H5
      ###### H6
      """
      
      # Default: levels 1-4
      headings = Extractor.extract_headings(content)
      assert length(headings) == 4
      
      # Custom levels
      headings = Extractor.extract_headings(content, max_level: 2)
      assert length(headings) == 2
      assert Enum.all?(headings, &(&1.level <= 2))
      
      headings = Extractor.extract_headings(content, min_level: 2, max_level: 3)
      assert length(headings) == 2
      assert Enum.all?(headings, &(&1.level >= 2 && &1.level <= 3))
    end

    test "extracts headings with metadata" do
      content = """
      ## Overview {#custom-id}
      ### Getting Started {.class-name}
      #### Advanced Topics {#advanced data-toc="Advanced"}
      """
      
      headings = Extractor.extract_headings(content)
      
      assert [
        %{text: "Overview", id: "custom-id"},
        %{text: "Getting Started", id: "getting-started"},
        %{text: "Advanced Topics", id: "advanced", display_text: "Advanced"}
      ] = headings
    end
  end

  describe "build_toc_tree/1" do
    test "builds hierarchical TOC structure" do
      headings = [
        %{level: 1, text: "Title", id: "title"},
        %{level: 2, text: "Section 1", id: "section-1"},
        %{level: 3, text: "Subsection 1.1", id: "subsection-1-1"},
        %{level: 2, text: "Section 2", id: "section-2"},
        %{level: 3, text: "Subsection 2.1", id: "subsection-2-1"},
        %{level: 3, text: "Subsection 2.2", id: "subsection-2-2"}
      ]
      
      tree = Extractor.build_toc_tree(headings)
      
      assert [
        %{
          level: 1,
          text: "Title",
          id: "title",
          children: [
            %{
              level: 2,
              text: "Section 1",
              id: "section-1",
              children: [
                %{level: 3, text: "Subsection 1.1", id: "subsection-1-1", children: []}
              ]
            },
            %{
              level: 2,
              text: "Section 2",
              id: "section-2",
              children: [
                %{level: 3, text: "Subsection 2.1", id: "subsection-2-1", children: []},
                %{level: 3, text: "Subsection 2.2", id: "subsection-2-2", children: []}
              ]
            }
          ]
        }
      ] = tree
    end

    test "handles multiple root-level headings" do
      headings = [
        %{level: 2, text: "Introduction", id: "introduction"},
        %{level: 2, text: "Installation", id: "installation"},
        %{level: 3, text: "Requirements", id: "requirements"},
        %{level: 2, text: "Usage", id: "usage"}
      ]
      
      tree = Extractor.build_toc_tree(headings)
      
      assert length(tree) == 3
      assert [
        %{text: "Introduction", children: []},
        %{text: "Installation", children: [%{text: "Requirements"}]},
        %{text: "Usage", children: []}
      ] = tree
    end

    test "handles irregular heading levels" do
      headings = [
        %{level: 1, text: "Title", id: "title"},
        %{level: 3, text: "Skipped Level", id: "skipped"},
        %{level: 2, text: "Back to Normal", id: "normal"}
      ]
      
      tree = Extractor.build_toc_tree(headings)
      
      # Should handle gracefully
      assert [
        %{
          text: "Title",
          children: [
            %{text: "Skipped Level", children: []},
            %{text: "Back to Normal", children: []}
          ]
        }
      ] = tree
    end

    test "empty headings returns empty tree" do
      assert [] = Extractor.build_toc_tree([])
    end
  end

  describe "extract_toc/2" do
    test "extracts and builds complete TOC" do
      content = """
      # Documentation
      
      ## Getting Started
      ### Installation
      ### Configuration
      
      ## Usage
      ### Basic Usage
      ### Advanced Usage
      """
      
      toc = Extractor.extract_toc(content)
      
      assert %{
        headings: headings,
        tree: tree,
        flat: flat_list
      } = toc
      
      assert length(headings) == 7
      assert length(tree) == 1
      assert length(flat_list) == 7
      
      # Verify flat list for easy navigation
      assert Enum.map(flat_list, & &1.id) == [
        "documentation",
        "getting-started", 
        "installation",
        "configuration",
        "usage",
        "basic-usage",
        "advanced-usage"
      ]
    end

    test "respects options" do
      content = """
      # H1
      ## H2
      ### H3
      #### H4
      ##### H5
      """
      
      toc = Extractor.extract_toc(content, max_level: 3)
      
      assert length(toc.headings) == 3
      assert Enum.all?(toc.headings, &(&1.level <= 3))
    end
  end
end