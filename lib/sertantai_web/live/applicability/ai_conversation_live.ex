defmodule SertantaiWeb.Applicability.AIConversationLive do
  @moduledoc """
  LiveView for AI-powered conversational organization profiling.
  
  Provides a chat-like interface where AI asks intelligent questions
  to discover comprehensive organization attributes for regulatory screening.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.AI.{ConversationSession, OrganizationAnalysis}
  alias Sertantai.Organizations

  @impl true
  def mount(%{"organization_id" => organization_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to conversation updates for real-time features
      Phoenix.PubSub.subscribe(Sertantai.PubSub, "ai_conversation:#{organization_id}")
    end

    # Load organization and initialize conversation session
    case load_organization_and_session(organization_id, socket.assigns.current_user) do
      {:ok, organization, session} ->
        socket = 
          socket
          |> assign(:organization, organization)
          |> assign(:conversation_session, session)
          |> assign(:conversation_history, session.conversation_history || [])
          |> assign(:current_message, "")
          |> assign(:ai_thinking, false)
          |> assign(:completion_percentage, session.completion_percentage || 0.0)
          |> assign(:page_title, "AI Conversation - #{organization.name}")

        # Start initial gap analysis if this is a new session
        if length(session.conversation_history || []) == 0 do
          send(self(), :start_conversation)
        end

        {:ok, socket}

      {:error, reason} ->
        socket = 
          socket
          |> put_flash(:error, "Unable to start conversation: #{reason}")
          |> redirect(to: ~p"/dashboard")

        {:ok, socket}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    # Redirect to dashboard if no organization_id provided
    socket = redirect(socket, to: ~p"/dashboard")
    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    %{conversation_session: session, organization: _organization} = socket.assigns

    # Add user message to conversation
    user_message = %{
      type: "user",
      content: message,
      timestamp: DateTime.utc_now()
    }

    # Update session with user message
    {:ok, updated_session} = ConversationSession.add_conversation_message(session, user_message)

    # Process user response and generate AI reply
    socket = 
      socket
      |> assign(:conversation_session, updated_session)
      |> assign(:conversation_history, updated_session.conversation_history)
      |> assign(:current_message, "")
      |> assign(:ai_thinking, true)

    # Process the user's response asynchronously
    send(self(), {:process_user_response, message})

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    # Ignore empty messages
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  @impl true
  def handle_info(:start_conversation, socket) do
    %{organization: organization, conversation_session: session} = socket.assigns

    # Perform initial gap analysis
    organization_profile = extract_organization_profile(organization)
    sector_context = determine_sector_context(organization)

    gap_analysis = OrganizationAnalysis.analyze_profile_gaps(organization_profile, sector_context)

    # Generate initial AI greeting and first question
    ai_message = %{
      type: "ai",
      content: generate_welcome_message(organization, gap_analysis),
      timestamp: DateTime.utc_now(),
      metadata: %{
        type: "welcome",
        gap_analysis: gap_analysis
      }
    }

    # Update session with AI message
    {:ok, updated_session} = ConversationSession.add_conversation_message(session, ai_message)

    socket = 
      socket
      |> assign(:conversation_session, updated_session)
      |> assign(:conversation_history, updated_session.conversation_history)
      |> assign(:ai_thinking, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:process_user_response, user_message}, socket) do
    %{conversation_session: session, organization: organization} = socket.assigns

    # Simulate AI processing delay for better UX
    Process.sleep(1000)

    # Generate contextual follow-up question
    organization_profile = extract_organization_profile(organization)
    conversation_context = build_conversation_context(session.conversation_history)

    # Get next question based on gap analysis and conversation history
    next_question = generate_next_question(user_message, organization_profile, conversation_context)

    ai_message = %{
      type: "ai", 
      content: next_question.question_text,
      timestamp: DateTime.utc_now(),
      metadata: %{
        type: "question",
        target_field: next_question.target_field,
        priority: next_question.priority
      }
    }

    # Update session with AI response
    {:ok, updated_session} = ConversationSession.add_conversation_message(session, ai_message)

    # Update completion percentage based on discovered data
    new_completion = calculate_completion_percentage(updated_session)
    {:ok, updated_session} = ConversationSession.update_session(updated_session, %{
      completion_percentage: new_completion
    })

    socket = 
      socket
      |> assign(:conversation_session, updated_session)
      |> assign(:conversation_history, updated_session.conversation_history)
      |> assign(:completion_percentage, new_completion)
      |> assign(:ai_thinking, false)

    # Broadcast update to any subscribers
    Phoenix.PubSub.broadcast(
      Sertantai.PubSub, 
      "ai_conversation:#{organization.id}",
      {:conversation_updated, updated_session}
    )

    {:noreply, socket}
  end

  # Private helper functions

  defp load_organization_and_session(organization_id, current_user) do
    with {:ok, organization} <- Organizations.Organization.read(organization_id),
         {:ok, session} <- get_or_create_session(organization, current_user) do
      {:ok, organization, session}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Organization not found"}
    end
  end

  defp get_or_create_session(organization, user) do
    # Try to find existing active session
    case ConversationSession.by_organization(organization.id) do
      [session | _] when session.session_status == :active ->
        {:ok, session}
      
      _ ->
        # Create new session
        ConversationSession.create(%{
          organization_id: organization.id,
          user_id: user.id,
          session_status: :active,
          conversation_history: [],
          discovered_attributes: %{},
          current_context: %{},
          completion_percentage: 0.0
        })
    end
  end

  defp extract_organization_profile(organization) do
    # Extract available organization data for AI analysis
    %{
      name: organization.name,
      organization_type: organization.organization_type,
      core_profile: organization.core_profile || %{},
      id: organization.id
    }
  end

  defp determine_sector_context(organization) do
    # Determine industry sector from organization data
    organization.core_profile["industry_sector"] || "GENERAL"
  end

  defp generate_welcome_message(organization, _gap_analysis) do
    """
    Hello! I'm here to help you complete your organization profile for #{organization.name}. 

    I've analyzed your current information and identified some key areas where additional details would help us provide more accurate regulatory guidance.

    Let's start with the most important information. What is your organization's primary business activity or main service?
    """
  end

  defp build_conversation_context(conversation_history) do
    # Build context from conversation history for AI question generation
    %{
      message_count: length(conversation_history),
      topics_covered: extract_topics_from_history(conversation_history),
      user_responses: extract_user_responses(conversation_history)
    }
  end

  defp extract_topics_from_history(history) do
    # Extract topics/fields that have been discussed
    history
    |> Enum.filter(&(&1.type == "ai" && &1.metadata))
    |> Enum.map(&(&1.metadata["target_field"]))
    |> Enum.reject(&is_nil/1)
  end

  defp extract_user_responses(history) do
    # Get all user responses for context
    history
    |> Enum.filter(&(&1.type == "user"))
    |> Enum.map(&(&1.content))
  end

  defp generate_next_question(_user_response, _org_profile, _context) do
    # Use QuestionGeneration resource to get next question
    # For now, return a placeholder question
    %{
      question_text: "Thank you for that information. Could you tell me more about the regions where you operate?",
      target_field: "operational_regions",
      priority: "high",
      question_type: "follow_up"
    }
  end

  defp calculate_completion_percentage(session) do
    # Calculate completion based on discovered attributes and conversation progress
    message_count = length(session.conversation_history || [])
    base_score = min(message_count * 10, 80)
    
    # Add bonus for specific attributes discovered
    attribute_bonus = map_size(session.discovered_attributes || %{}) * 5
    
    min(base_score + attribute_bonus, 100) / 100.0
  end
end