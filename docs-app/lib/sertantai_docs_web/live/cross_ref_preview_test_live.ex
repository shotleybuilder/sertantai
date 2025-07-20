defmodule SertantaiDocsWeb.Live.CrossRefPreviewTestLive do
  @moduledoc """
  Test LiveView for cross-reference preview component integration testing.
  This is used by the test suite to verify preview functionality.
  """
  
  use SertantaiDocsWeb, :live_view
  alias SertantaiDocsWeb.Components.CrossRefPreview
  
  @impl true
  def mount(_params, session, socket) do
    # Allow tests to provide a PID to send messages to
    test_pid = session["test_pid"]
    
    {:ok, assign(socket, 
      cross_refs: [],
      preview_cache: %{},
      loading_preview: nil,
      test_pid: test_pid
    )}
  end
  
  @impl true
  def handle_info({:update_cross_refs, cross_refs}, socket) do
    {:noreply, assign(socket, cross_refs: cross_refs)}
  end
  
  @impl true
  def handle_info({:load_preview_data, target, type}, socket) do
    # Check cache first
    cache_key = "#{type}:#{target}"
    
    if Map.get(socket.assigns.preview_cache, cache_key) do
      # Already cached, notify test process immediately if needed
      if socket.assigns[:test_pid] do
        send(socket.assigns.test_pid, {:preview_data_loaded, target, socket.assigns.preview_cache[cache_key]})
      end
      {:noreply, socket}
    else
      # Simulate loading preview data
      send(self(), {:preview_data_loaded, target, generate_preview_data(type, target)})
      {:noreply, assign(socket, loading_preview: {target, type})}
    end
  end
  
  @impl true
  def handle_info({:preview_data_loaded, target, data}, socket) do
    # Update cross_refs with preview data
    updated_refs = Enum.map(socket.assigns.cross_refs, fn ref ->
      if ref.target == target do
        Map.put(ref, :preview_data, data)
      else
        ref
      end
    end)
    
    # Update cache
    cache_key = "#{data.type}:#{target}"
    updated_cache = Map.put(socket.assigns.preview_cache, cache_key, data)
    
    # Notify test process if needed
    if socket.assigns[:test_pid] do
      send(socket.assigns.test_pid, {:preview_data_loaded, target, data})
    end
    
    {:noreply, assign(socket, 
      cross_refs: updated_refs,
      preview_cache: updated_cache,
      loading_preview: nil
    )}
  end
  
  @impl true
  def handle_info({:update_document, _markdown}, socket) do
    # Simulate processing markdown and extracting cross-references
    cross_refs = [
      %{
        id: "ref1",
        type: :ash,
        target: "Sertantai.Accounts.User",
        text: "User Resource",
        url: "/api/ash/Sertantai.Accounts.User",
        valid: true,
        preview_data: %{
          resource_type: "ash_resource",
          domain: "Sertantai.Accounts",
          description: "User account resource"
        }
      }
    ]
    
    {:noreply, assign(socket, cross_refs: cross_refs)}
  end
  
  @impl true
  def handle_event("load_preview", %{"target" => target, "type" => type}, socket) do
    type_atom = String.to_existing_atom(type)
    
    # Check cache first
    cache_key = "#{type}:#{target}"
    if preview_data = socket.assigns.preview_cache[cache_key] do
      # Already cached, notify immediately
      if socket.assigns[:test_pid] do
        send(socket.assigns.test_pid, {:preview_loaded, target, preview_data})
      end
      {:noreply, socket}
    else
      # Simulate async loading
      send(self(), {:load_preview_data, target, type_atom})
      {:noreply, socket}
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="cross-ref-preview-test-container">
      <h1>Cross-Reference Preview Test Page</h1>
      
      <div class="cross-refs">
        <%= for ref <- @cross_refs do %>
          <div class="cross-ref-item" id={"ref-#{ref.id}"}>
            <CrossRefPreview.cross_ref_link cross_ref={ref} />
            <%= if ref[:preview_data] do %>
              <CrossRefPreview.preview_tooltip cross_ref={ref} />
            <% end %>
          </div>
        <% end %>
      </div>
      
      <%= if @loading_preview do %>
        <div class="loading-indicator">
          Loading preview for: <%= elem(@loading_preview, 0) %>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Private functions
  
  defp generate_preview_data(:ash, target) do
    %{
      type: :ash,
      target: target,
      resource_type: "ash_resource",
      domain: extract_domain(target),
      description: "Mock Ash resource for #{target}",
      actions: ["create", "read", "update", "destroy"],
      attributes: ["id", "name", "email"],
      relationships: ["user_identities"]
    }
  end
  
  defp generate_preview_data(:exdoc, target) do
    %{
      type: :exdoc,
      target: target,
      module_type: "elixir_module",
      description: "Mock module documentation for #{target}",
      functions: ["function1/1", "function2/2"],
      examples: ["#{target}.function1(:example)"],
      since: "1.0.0"
    }
  end
  
  defp generate_preview_data(type, target) do
    %{
      type: type,
      target: target,
      title: "Mock #{type} Documentation",
      description: "Mock documentation for #{target}",
      category: String.capitalize(to_string(type))
    }
  end
  
  defp extract_domain(resource) do
    resource
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end
end