# Phase 3 Implementation Plan: AI Question Generation & Data Discovery

## 🎯 Overview

**Project:** AI-Driven Applicability Screening Agent  
**Phase:** 3 of 4 - AI Question Generation & Data Discovery  
**Duration:** 8-10 weeks  
**Complexity:** High  
**Dependencies:** Phase 2 complete + AshAI Integration  

---

## 🚀 Phase 3 Goals

Transform the Phase 2 real-time progressive screening into an intelligent, conversational system that uses AI to discover comprehensive organization attributes through natural language interaction.

### Success Definition
Users engage in intelligent conversations with AI that discovers 80%+ of relevant organization attributes, with type-safe mapping to organization schema and graceful fallback mechanisms.

### Key Enhancement over Phase 2
- **Intelligent Discovery** - AI analyzes organization gaps and generates targeted questions
- **Conversational Interface** - Natural language collection replaces static forms  
- **Type-Safe Integration** - AshAI provides native Ash Framework patterns
- **Adaptive Questioning** - Context-aware follow-up questions based on responses

---

## 🏗️ Technical Architecture

### Core AshAI Integration Strategy

```
Phase 3: AshAI-Powered Intelligence Architecture

┌─────────────────────────────────────────────────────────────┐
│ Native Ash Framework AI Integration                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────┐    ┌─────────────────┐                │
│ │ AI Profile Gap  │    │ Question        │                │
│ │ Analysis        │◄──►│ Generation      │                │
│ │ (Ash Actions)   │    │ (Prompt Actions)│                │
│ └─────────────────┘    └─────────────────┘                │
│          │                       │                         │
│          ▼                       ▼                         │
│ ┌─────────────────┐    ┌─────────────────┐                │
│ │ Conversational  │    │ AI Response     │                │
│ │ LiveView UI     │◄──►│ Processing      │                │
│ │ (AshPhoenix)    │    │ (AI Changes)    │                │
│ └─────────────────┘    └─────────────────┘                │
│          │                       │                         │
│          ▼                       ▼                         │
│ ┌─────────────────────────────────────────┐                │
│ │ Enhanced Organization Profile           │                │
│ │ (Type-Safe Schema Validation)           │                │
│ └─────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack
- **AI Framework:** AshAI with LangChain integration
- **Frontend:** Phoenix LiveView with conversational UI components
- **Backend:** Ash Framework actions, calculations, and changes
- **Validation:** Native Ash attribute types and constraints
- **Monitoring:** Standard Ash telemetry and error handling

---

## 📋 Implementation Roadmap

### Week 1-2: AshAI Foundation & Dependencies

#### 1.1 Dependency Setup
**Goal:** Add and configure AshAI framework integration

**Tasks:**
- Add AshAI dependencies to mix.exs
- Configure OpenAI API credentials and environment variables
- Set up LangChain integration for prompt management
- Create base AI configuration module

**Dependencies to Add:**
```elixir
# Add to mix.exs deps
{:ash_ai, "~> 0.1"},
{:langchain, "~> 0.3"},
{:openai, "~> 0.6"},
{:req, "~> 0.5"}
```

**Deliverables:**
- [ ] AshAI dependencies installed and configured
- [ ] OpenAI API connection tested
- [ ] Base AI configuration module created
- [ ] Environment variables documented

#### 1.2 AI Resource Architecture
**Goal:** Create foundational Ash resources for AI functionality

**Key Resources to Create:**
- `Sertantai.AI.OrganizationAnalysis` - Profile gap analysis
- `Sertantai.AI.QuestionGeneration` - AI question generation  
- `Sertantai.AI.ConversationSession` - Session management
- `Sertantai.AI.ResponseProcessing` - Schema mapping

**Resource Structure:**
- Attributes for AI session data, confidence scores, discovered fields
- Relationships linking to organizations and users
- AshAI tools configuration for exposing actions
- Prompt actions for AI-powered functionality

**Deliverables:**
- [ ] AI resource modules created with AshAI integration
- [ ] Basic prompt actions defined
- [ ] Resource relationships established
- [ ] Unit tests for resource creation

### Week 3-4: Profile Gap Analysis & Question Generation

#### 3.1 Intelligent Gap Analysis Engine
**Goal:** AI analyzes organization profiles to identify missing critical data

**Core Functionality:**
- Sector-specific field prioritization
- Regulatory impact scoring for missing fields
- Similar organization pattern matching
- Gap analysis prompt actions

**Implementation Strategy:**
- Create `analyze_profile_gaps` action using AshAI prompt functionality
- Implement sector-specific field requirement mapping
- Build confidence scoring for gap analysis results
- Add caching for common gap analysis patterns

**Deliverables:**
- [ ] Profile gap analysis action implemented
- [ ] Sector-specific field requirements defined
- [ ] Gap analysis confidence scoring working
- [ ] Caching strategy for common patterns

#### 3.2 AI Question Generation System
**Goal:** Generate contextual, targeted questions based on gap analysis

**Core Functionality:**
- Sector-specific question templates
- Dynamic question prioritization
- Context-aware follow-up logic
- Question regulatory impact scoring

**AshAI Integration:**
- Prompt actions for question generation
- Type-safe question structure validation
- Built-in error handling for AI failures
- Automatic retry mechanisms

**Deliverables:**
- [ ] Question generation prompt actions created
- [ ] Sector-specific question templates implemented  
- [ ] Question prioritization algorithm working
- [ ] Follow-up question logic functional

### Week 5-6: Conversational UI & Live Interaction

#### 5.1 Conversational LiveView Interface
**Goal:** Create chat-like interface for natural language interaction

**UI Components:**
- Chat message display with conversation history
- Real-time typing indicators and AI response streaming
- Question context and regulatory impact display
- Progress indicators for profile completeness

**LiveView Integration:**
- Real-time updates via Phoenix.PubSub
- Session management for conversation state
- Graceful error handling for AI failures
- Mobile-responsive conversational design

**Deliverables:**
- [ ] Conversational LiveView module created
- [ ] Chat UI components implemented
- [ ] Real-time conversation updates working
- [ ] Mobile-responsive design completed

#### 5.2 AI Response Processing & Schema Mapping
**Goal:** Convert natural language responses to structured organization data

**Core Functionality:**
- Entity extraction from conversational responses
- Confidence scoring for extracted data
- Type-safe mapping to organization schema
- Conflict resolution for contradictory data

**AshAI Integration:**
- AI changes for automatic schema updates
- Validation using Ash attribute constraints
- Error handling for invalid extractions
- Audit trails for AI-discovered data

**Deliverables:**
- [ ] Response processing actions implemented
- [ ] Schema mapping logic working
- [ ] Confidence scoring functional
- [ ] Audit trail system active

### Week 7-8: Session Management & Reliability

#### 7.1 Conversation Session Management
**Goal:** Persistent, resumable AI conversation sessions

**Session Features:**
- Conversation state persistence
- Multi-session organization profiling
- Session resumption after interruptions
- Conversation history and context maintenance

**Implementation:**
- Ash resource for conversation sessions
- Session state management via Ash changes
- Context preservation across sessions
- Session expiration and cleanup

**Deliverables:**
- [ ] Session management resource created
- [ ] Session persistence working
- [ ] Session resumption functional
- [ ] Context preservation tested

#### 7.2 Error Handling & Fallback Mechanisms
**Goal:** Graceful degradation when AI services fail

**Fallback Strategies:**
- Static form fallback when AI unavailable
- Cached question sets for common scenarios
- Manual data entry with validation
- Error recovery and retry mechanisms

**Reliability Features:**
- AI service health monitoring
- Automatic fallback triggering
- User notification of service issues
- Performance monitoring and alerting

**Deliverables:**
- [ ] Fallback mechanisms implemented
- [ ] Service health monitoring active
- [ ] Error recovery working
- [ ] Performance monitoring configured

---

## 🎛️ Technical Implementation Details

### AshAI Resource Examples

#### Gap Analysis Resource
```elixir
# High-level structure - detailed implementation during development
defmodule Sertantai.AI.OrganizationAnalysis do
  use Ash.Resource, extensions: [AshAI]
  
  attributes do
    uuid_primary_key :id
    attribute :organization_id, :uuid
    attribute :analysis_type, :atom
    attribute :gap_analysis_result, :map
    attribute :confidence_score, :decimal
    timestamps()
  end
  
  tools do
    tool :analyze_gaps, __MODULE__, :analyze_profile_gaps
  end
  
  actions do
    action :analyze_profile_gaps, :map do
      argument :organization_profile, :map
      argument :sector_context, :string
      
      run prompt(
        LangChain.ChatModels.ChatOpenAI.new!(%{model: "gpt-4o"}),
        # Detailed prompt template for gap analysis
        tools: true
      )
    end
  end
end
```

### LiveView Integration Pattern

#### Conversational Interface Structure
```elixir
# High-level structure - detailed implementation during development
defmodule SertantaiWeb.ApplicabilityLive.AIConversation do
  use SertantaiWeb, :live_view
  
  def mount(%{"organization_id" => org_id}, _session, socket) do
    # Initialize AI conversation session
    # Load organization profile
    # Start gap analysis
    # Set up real-time updates
  end
  
  def handle_event("user_message", %{"message" => message}, socket) do
    # Process user response via AshAI
    # Update organization profile
    # Generate follow-up questions
    # Update UI with real-time feedback
  end
end
```

### Database Schema Extensions

#### AI Session Tables
- `ai_conversation_sessions` - Session management and persistence
- `ai_discovered_attributes` - Audit trail for AI-found data
- `ai_question_history` - Question generation and response tracking
- `ai_confidence_scores` - Confidence tracking for discovered data

---

## 📊 Success Metrics & Validation

### Performance Targets
- **Question Generation Time:** <5 seconds for sector-specific questions
- **Response Processing:** <2 seconds for natural language to schema mapping
- **Session Persistence:** 100% reliability for conversation state
- **Fallback Response:** <1 second to activate when AI unavailable

### Quality Metrics  
- **Attribute Discovery:** 80%+ relevant organization attributes found
- **Mapping Accuracy:** 90% accuracy for conversation-to-schema mapping
- **User Satisfaction:** >4/5 rating for conversational experience
- **Completion Rate:** >75% of users complete AI-enhanced profiling

### Technical Quality
- **Type Safety:** 100% of AI responses validated via Ash constraints
- **Error Handling:** Graceful degradation for all AI service failures
- **Monitoring:** Comprehensive telemetry for AI service performance
- **Test Coverage:** 90%+ coverage for AI integration logic

---

## 🔄 Dependencies & Integration Points

### Phase 2 Dependencies
- Enhanced organization schema from Phase 2
- Real-time query optimization and caching
- Progressive screening LiveView components
- Database performance optimizations

### Phase 4 Preparation
- AI-discovered data structure for comprehensive analysis
- Confidence scoring framework for legal review
- Audit trail system for professional validation
- Data quality metrics for accuracy assessment

### External Dependencies
- OpenAI API access and rate limiting
- AshAI framework stability and updates
- LangChain prompt management
- Network reliability for AI service calls

---

## ⚠️ Risk Mitigation & Contingencies

### Technical Risks
- **AI Service Outages:** Comprehensive fallback to static forms
- **Response Quality Issues:** Confidence scoring and manual review
- **Performance Degradation:** Caching and optimization strategies
- **Type Safety Failures:** Robust validation and error handling

### Implementation Risks
- **AshAI Integration Complexity:** Start with simple prompt actions
- **User Experience Challenges:** Iterative UI testing and refinement
- **Data Quality Concerns:** Confidence scoring and validation
- **Session Management Issues:** Simple state persistence with cleanup

### Mitigation Strategies
- **Progressive Enhancement:** Build on Phase 2 foundation incrementally
- **Comprehensive Testing:** Unit and integration tests for all AI components
- **Performance Monitoring:** Real-time monitoring and alerting
- **User Feedback:** Continuous UI/UX iteration based on user testing

---

## 📅 Milestone Schedule

### Week 1-2: Foundation (25% Complete)
- ✅ AshAI dependencies and configuration
- ✅ Base AI resource architecture
- ✅ OpenAI integration testing
- ✅ Development environment setup

### Week 3-4: Core AI Engine (50% Complete)
- ✅ Profile gap analysis implementation
- ✅ Question generation system
- ✅ Sector-specific templates
- ✅ Basic confidence scoring

### Week 5-6: User Interface (75% Complete)
- ✅ Conversational LiveView implementation
- ✅ Real-time chat interface
- ✅ AI response processing
- ✅ Schema mapping functionality

### Week 7-8: Production Ready (100% Complete)
- ✅ Session management system
- ✅ Error handling and fallbacks
- ✅ Performance optimization
- ✅ Comprehensive testing and monitoring

---

## 🚀 Phase 3 Success Definition

**Primary Goal Achieved:** Users engage in intelligent, contextual conversations that discover comprehensive organization attributes through natural language, with native Ash Framework integration providing type safety and reliability.

**Key Success Indicators:**
- AI discovers 80%+ relevant organization attributes through conversation
- Question generation responds within 5 seconds using AshAI prompts
- Conversation-to-schema mapping achieves 90% accuracy via type-safe validation
- Graceful degradation using standard Ash resource patterns
- AI integration monitoring via native Ash telemetry

**Phase 4 Readiness:** Comprehensive organization profiles with AI-discovered attributes, confidence scoring, and audit trails ready for advanced matching algorithms and legal review integration.