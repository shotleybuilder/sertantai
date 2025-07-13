
# Applicability Screening AI Agent

## 🎯 Overview
This document outlines strategies to build an **AI-driven applicability screening agent** to match UK Legal Register and Tracker (UK LRT) records to duty holders, based on information provided by a user through an AI chat interface. Built using **Elixir/Phoenix** with **Ash Framework** for business logic, this system leverages **AshAI** for native AI integration deployed on **Digital Ocean**.

---

## 🚀 Four-Phase Applicability Screening Strategy

*Restructured for clear deliverables, self-contained builds, and measurable success criteria*

### Phase 1: Basic Screening Foundation
**Goal:** Static organization profiling with basic database matching  
**Duration:** 4-6 weeks | **Complexity:** Low | **Dependencies:** None

#### Technical Scope
- Organization schema implementation in `lib/sertantai/organizations/`
- Simple UK LRT queries (family, geo_extent, live status only)
- Basic Phoenix LiveView forms with validation
- Core persistence layer (no AI components)

#### Key Features
1. **Organization Registration Flow**
   - Core identity fields: `organization_name`, `organization_type`, `headquarters_region`
   - Basic classification: `primary_sic_code`, `industry_sector`
   - Simple validation rules and error handling

2. **Basic Applicability Matching**
   - Direct field mapping: `industry_sector` → `family`
   - Geographic filtering: `headquarters_region` → `geo_extent`
   - Status filtering: `live` = "✔ In force"
   - Simple count display of potentially applicable laws

3. **Data Foundation**
   - Organization schema with core profile structure
   - Basic JSONB queries for `family` and `geo_extent`
   - Simple caching for common queries

#### Success Criteria & Deliverables
- ✅ User can register organization and get basic law count
- ✅ Database queries respond within 2 seconds
- ✅ Organization profile validation works for 95% of UK company types
- ✅ Unit tests for core matching logic with 90%+ coverage
- ✅ Performance benchmarks established and documented

### Phase 2: Real-Time Progressive Screening
**Goal:** Live query refinement as users enter data  
**Duration:** 6-8 weeks | **Complexity:** Medium | **Dependencies:** Phase 1 complete

#### Technical Scope
- Real-time database querying via Phoenix LiveView
- JSONB role matching for `duty_holder` and `role` arrays
- Employee/turnover threshold-based filtering
- Database optimization and indexing strategy

#### Key Features
1. **Progressive Data Collection**
   - Step-by-step form with live updates
   - Size thresholds: `total_employees`, `annual_turnover`
   - Geographic scope: `operational_extent`, `operational_regions`
   - Real-time law count updates as user types

2. **Enhanced Database Queries**
   - JSONB array queries for role matching
   - Threshold-based filtering (5+, 50+, 250+ employees)
   - Multi-field compound queries
   - Optimized indexing for performance

3. **Performance & Caching**
   - Query result caching for common organization types
   - Database indexes on JSONB fields
   - Response time monitoring and optimization

#### Success Criteria & Deliverables
- ✅ Real-time law count updates with <500ms latency
- ✅ Progressive query refinement for all core schema fields
- ✅ Performance maintained <2s for complex queries
- ✅ JSONB indexing strategy implemented and load tested
- ✅ Concurrent user capacity validated (100+ users)

### Phase 3: AI Question Generation & Data Discovery
**Goal:** Conversational data collection using AI  
**Duration:** 8-10 weeks | **Complexity:** High | **Dependencies:** Phase 2 + AshAI Integration

#### Technical Scope
- AshAI framework integration for native AI actions
- Conversational UI for organization profiling
- AI-to-schema field mapping via Ash resources
- Type-safe AI responses with automatic validation

#### Key Features
1. **Intelligent Question Generation**
   - AI analyzes basic profile to identify data gaps
   - Sector-specific questioning based on organization schema
   - Context-aware follow-up questions
   - Question prioritization by regulatory impact

2. **Conversational Data Collection**
   - Chat interface for complex organization attributes
   - Natural language to schema field mapping
   - Progressive enhancement of organization profile
   - Session management and conversation persistence

3. **AI Integration & Reliability**
   - AshAI native integration with Ash actions as AI tools
   - Built-in fallback mechanisms using Ash patterns
   - Confidence scoring for AI-discovered data
   - Type-safe error handling via Ash changesets

#### Success Criteria & Deliverables
- ✅ AI discovers 80%+ relevant organization attributes
- ✅ Question generation responds within 5 seconds
- ✅ Conversation-to-schema mapping 90% accurate via AshAI
- ✅ Graceful degradation using Ash resource patterns
- ✅ AI integration monitoring via standard Ash telemetry

### Phase 4: Comprehensive Analysis & Legal Review
**Goal:** Full applicability assessment with legal validation  
**Duration:** 10-12 weeks | **Complexity:** High | **Dependencies:** Phase 3 + Legal Framework

#### Technical Scope
- Multi-layer matching algorithms
- Confidence scoring methodology
- AI explanation generation
- Legal review workflow integration

#### Key Features
1. **Advanced Matching Algorithms**
   - Multi-dimensional applicability scoring
   - Semantic content analysis of regulation descriptions
   - Role hierarchy and relationship mapping
   - Amendment/rescission relationship analysis

2. **Legal Compliance Framework**
   - Professional legal review workflow
   - Disclaimer and limitation systems
   - Audit trails for all assessments
   - Professional indemnity considerations

3. **Comprehensive Results**
   - Detailed regulation explanations
   - Confidence scores for each match
   - Prioritized compliance action plans
   - Export capabilities for legal review

#### Success Criteria & Deliverables
- ✅ Complete regulatory assessment with justifications
- ✅ 90% accuracy vs. legal professional review
- ✅ Explanation quality rated >4/5 by legal professionals
- ✅ Legal review workflow integrated and tested
- ✅ Professional validation of AI recommendations

---

## 🧩 Using MCP (Model–Context–Prompt)

### Where to use MCP pattern
- ✅ **After DB retrieval:** to explain or justify why obligations apply.  
- ✅ **For dynamic query generation:** use AI to build/refine queries.  
- ✅ **During clarification:** generate follow-up questions.  
- ✅ **As validation step:** cross-check applicability.

### Schema-Enhanced MCP Examples

| Part    | Basic Usage | Schema-Enhanced Usage |
|---------|-------------|----------------------|
| **Model**   | GPT or similar LLM | GPT with schema-aware prompting |
| **Context** | User profile + retrieved laws | User profile + **schema fields**: `family`, `role`, `duty_holder`, `geo_extent` + matched records |
| **Prompt**  | "Explain why these obligations apply" | "Analyze why law X applies to user Y based on: sector=`{family}`, role=`{duty_holder}`, location=`{geo_extent}`, purpose=`{purpose}`" |

#### Specific Schema Field Prompting
```
Model: GPT-4
Context: {
  "user_sector": "Construction",
  "user_role": "Site Manager", 
  "location": "England",
  "matched_records": [
    {
      "name": "UK_si_2007_320",
      "family": "💙 CONSTRUCTION",
      "duty_holder": ["Site Manager", "Principal Contractor"],
      "geo_extent": "England and Wales",
      "md_description": "Construction site safety regulations..."
    }
  ]
}
Prompt: "Explain the applicability of UK_si_2007_320 to a Site Manager in England, 
highlighting the specific duties from the duty_holder field and geographic relevance."
```

---

## 🚨 Critical Implementation Requirements

*Essential components that must be implemented across all phases for production readiness*

### Legal Compliance Framework
**Required before any production deployment**

```elixir
defmodule Sertantai.Legal.ComplianceFramework do
  @moduledoc """
  Legal compliance framework for AI-generated regulatory advice
  Ensures professional standards and liability protection
  """
  
  def generate_disclaimer(assessment_type) do
    """
    IMPORTANT LEGAL DISCLAIMER
    
    This applicability screening is generated by AI analysis and is provided for 
    guidance purposes only. It does not constitute legal advice and should not be 
    relied upon without professional legal review.
    
    Users must:
    - Seek professional legal advice for definitive compliance guidance
    - Verify all regulatory requirements with relevant authorities
    - Conduct their own legal research for specific circumstances
    
    #{organization_name} accepts no liability for decisions made based on this screening.
    """
  end
  
  def create_legal_review_workflow(assessment) do
    # 1. Flag high-impact regulations for mandatory review
    # 2. Route assessments to qualified legal professionals  
    # 3. Track review status and approval
    # 4. Maintain audit trail of all legal validations
    # 5. Update AI models based on professional feedback
  end
  
  def audit_trail_for_assessment(assessment_id, user_id, organization_id) do
    # Complete audit logging for compliance and liability protection
    AuditLog.create(%{
      assessment_id: assessment_id,
      user_id: user_id,
      organization_id: organization_id,
      ai_version: get_ai_model_version(),
      data_sources: ["uk_lrt_#{get_data_version()}", "organization_profile"],
      legal_review_status: "pending",
      disclaimer_accepted: true,
      timestamp: DateTime.utc_now()
    })
  end
end
```

### Data Quality Assurance Framework
**Required for reliable applicability screening**

```elixir
defmodule Sertantai.DataQuality do
  @moduledoc """
  Comprehensive data quality and validation framework
  Ensures accuracy and consistency of regulatory data
  """
  
  def monitor_uk_lrt_updates() do
    # 1. Daily monitoring of UK LRT database changes
    # 2. Automated validation of new/amended regulations
    # 3. Impact assessment for existing assessments
    # 4. Notification system for critical changes
    # 5. Versioning of regulation data for consistency
  end
  
  def validate_organization_profile(profile) do
    validations = [
      companies_house_verification(profile.registration_number),
      sic_code_validation(profile.primary_sic_code),
      geographic_scope_consistency(profile.operational_regions),
      employee_count_reasonableness(profile.total_employees, profile.annual_turnover),
      data_completeness_check(profile)
    ]
    
    case Enum.all?(validations, &(&1.valid?)) do
      true -> {:ok, profile}
      false -> {:error, extract_validation_errors(validations)}
    end
  end
  
  def detect_duplicate_organizations(new_organization) do
    # Advanced duplicate detection using multiple criteria:
    # - Registration numbers (Companies House, VAT, Charity)
    # - Name similarity with fuzzy matching
    # - Address matching for same location
    # - Email domain cross-reference
    # - Director/key personnel overlap
  end
  
  def data_consistency_validation() do
    # Cross-validation between data sources:
    # - Organization profiles vs Companies House data
    # - SIC codes vs business activities descriptions
    # - Employee counts vs turnover reasonableness
    # - Geographic claims vs operational evidence
  end
end
```

### Performance & Reliability Framework  
**Required for production-ready system**

```elixir
defmodule Sertantai.Performance do
  @moduledoc """
  Performance optimization and reliability framework
  Ensures system scalability and response time targets
  """
  
  def implement_database_optimization() do
    # 1. JSONB indexing strategy for UK LRT queries
    create_indexes([
      "CREATE INDEX CONCURRENTLY idx_uk_lrt_family_gin ON uk_lrt USING gin(family);",
      "CREATE INDEX CONCURRENTLY idx_uk_lrt_duty_holder_gin ON uk_lrt USING gin(duty_holder);", 
      "CREATE INDEX CONCURRENTLY idx_uk_lrt_geo_extent ON uk_lrt(geo_extent);",
      "CREATE INDEX CONCURRENTLY idx_uk_lrt_live ON uk_lrt(live) WHERE live = '✔ In force';",
      "CREATE INDEX CONCURRENTLY idx_organizations_sic ON organizations((core_profile->>'primary_sic_code'));"
    ])
    
    # 2. Query result caching for common patterns
    implement_query_cache()
    
    # 3. Connection pooling optimization
    optimize_database_connections()
  end
  
  def query_caching_strategy() do
    # Multi-layer caching approach:
    # - Level 1: In-memory ETS cache for frequent organization types
    # - Level 2: Redis cache for complex query results  
    # - Level 3: Database materialized views for common joins
    # - Cache invalidation strategy for data updates
  end
  
  def monitoring_and_alerting() do
    # Comprehensive monitoring for:
    # - Database query performance and slow query detection
    # - AI service response times and failure rates
    # - User session performance and error rates
    # - Resource utilization and scaling triggers
    # - Legal review queue backlog monitoring
  end
  
  def graceful_degradation_strategies() do
    # Fallback mechanisms:
    # - AI service failures → basic rule-based screening via Ash actions
    # - Database performance issues → cached results
    # - High load conditions → queue-based processing
    # - AshAI unavailable → static form-based data collection
  end
end
```

### Regulation Change Management
**Required for maintaining accuracy over time**

```elixir
defmodule Sertantai.RegulationChangeManagement do
  @moduledoc """
  Handles updates, amendments, and revocations in UK legal register
  Ensures existing assessments remain current and accurate
  """
  
  def handle_regulation_update(regulation_change) do
    case regulation_change.type do
      :new_regulation ->
        # 1. Analyze impact on existing organization profiles
        # 2. Identify organizations that may be newly affected
        # 3. Queue re-assessments for high-impact cases
        # 4. Update AI training data with new regulation
        
      :amendment ->
        # 1. Identify existing assessments that reference amended regulation
        # 2. Analyze scope and impact of amendment
        # 3. Flag assessments for legal review if material changes
        # 4. Update cached query results
        
      :revocation ->
        # 1. Remove revoked regulation from all active assessments
        # 2. Notify organizations of changes to their compliance profile
        # 3. Update applicability counts and explanations
        # 4. Archive historical assessments with revoked regulations
    end
  end
  
  def assessment_versioning(assessment_id) do
    # Version control for assessments:
    # - Snapshot of UK LRT data version used
    # - Organization profile version at time of assessment
    # - AI model version and confidence scores
    # - Legal review status and approvals
    # - Change history and reasoning for updates
  end
  
  def impact_analysis_for_changes(regulation_changes) do
    # Analyze downstream impact:
    # - Number of organizations affected
    # - Severity of compliance changes
    # - Priority ranking for re-assessment
    # - Resource requirements for updates
    # - Communication strategy for affected users
  end
end
```

---

## 🤖 Using AshAI Framework

### Why
- Native Elixir AI integration with type safety and Ash Framework patterns, eliminating external service complexity.

### How in this architecture
- Main Phoenix application handles:
  - Phoenix LiveView web UI
  - Ash Framework business logic with AI-powered actions
  - PostgreSQL database (existing uk_lrt schema)
  - User selection persistence system
- AshAI Framework provides:
  - AI-powered Ash actions for question generation
  - Type-safe conversation-to-schema mapping
  - Built-in prompt management and validation
  - Native Elixir performance without network overhead
- Keeps deployment simple while adding powerful AI capabilities.

### Four-Phase Progressive Pipeline

#### Phase 1: Basic Screening Foundation
```
[Organization Registration → Phoenix LiveView Forms]
   ↓
[Core Data Entry → Basic Validation]
   │ ├─ Organization identity fields
   │ ├─ SIC code classification
   │ ├─ Geographic scope selection
   │ └─ Employee count input
   ↓
[Simple Database Matching → Ash Framework]
   │ ├─ Filter: live = "✔ In force"
   │ ├─ Match: industry_sector → family
   │ ├─ Match: headquarters_region → geo_extent
   │ └─ Basic threshold checks
   ↓
[Basic Results Display → Static Count]
   └─ "X potentially applicable laws identified"
```

#### Phase 2: Real-Time Progressive Screening
```
[Enhanced Form → Live Updates via Phoenix LiveView]
   ↓
[Progressive Data Entry → Real-Time Query Refinement]
   │ ├─ Employee thresholds (5+, 50+, 250+)
   │ ├─ Turnover-based filtering
   │ ├─ Multi-region operations
   │ └─ Role-based matching (duty_holder)
   ↓
[JSONB Database Queries → Optimized Performance]
   │ ├─ Indexed JSONB array matching
   │ ├─ Compound filtering logic
   │ ├─ Cached results for common types
   │ └─ Sub-500ms response targets
   ↓
[Live UI Updates → Real-Time Feedback]
   └─ Dynamic law count, threshold notifications, progress indicators
```

#### Phase 3: AI Question Generation & Data Discovery
```
[Profile Analysis → AI Gap Detection via AshAI]
   ↓
[Native Ash Actions → Intelligent Question Generation]
   │ ├─ Sector-specific questioning (prompt actions)
   │ ├─ Risk assessment priorities (AI calculations)
   │ ├─ Compliance framework analysis (AI tools)
   │ └─ Follow-up question logic (Ash changes)
   ↓
[Conversational Interface → Natural Language Collection]
   │ ├─ Chat UI with AshPhoenix forms
   │ ├─ Context-aware responses via AI actions
   │ ├─ Session management using Ash resources
   │ └─ Type-safe error handling
   ↓
[AI-to-Schema Mapping → Enhanced Profile]
   └─ 80%+ organization attribute discovery with validation
```

#### Phase 4: Comprehensive Analysis & Legal Review
```
[Complete Profile → Multi-Layer Matching]
   ↓
[Advanced Algorithms → Confidence Scoring]
   │ ├─ Multi-dimensional applicability analysis
   │ ├─ Semantic content matching
   │ ├─ Role hierarchy mapping
   │ └─ Amendment relationship analysis
   ↓
[AI Explanation Generation → Legal Review Queue]
   │ ├─ Detailed regulation explanations
   │ ├─ Professional legal validation
   │ ├─ Disclaimer and liability framework
   │ └─ Audit trail maintenance
   ↓
[Comprehensive Results → Validated Assessment]
   └─ Complete compliance roadmap with legal approval
```

---

## ⚙️ Tech Stack Summary by Phase

| Component | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|-----------|---------|---------|---------|---------|
| **Data Storage** | PostgreSQL + Ash | + JSONB indexing | + Caching layer | + Version control |
| **UI Framework** | Phoenix LiveView | + Real-time updates | + Chat interface | + Results dashboard |
| **Business Logic** | Basic Ash queries | + Complex filtering | + AI integration | + Multi-layer matching |
| **AI Integration** | None | None | AshAI Framework | + Explanation generation |
| **Performance** | Basic queries | Optimized + cached | + AI monitoring | + Legal review queue |
| **Legal Framework** | Basic validation | Data quality checks | + AI disclaimers | Full compliance framework |

### Implementation Dependencies by Phase
- **Phase 1:** Core Ash + Phoenix + PostgreSQL
- **Phase 2:** + Database optimization + Caching + Performance monitoring  
- **Phase 3:** + AshAI integration + AI-powered Ash actions + Type-safe fallbacks
- **Phase 4:** + Legal review workflow + Professional validation + Compliance framework

## ✅ Progressive Benefits
- **Phase 1:** Immediate value with basic screening capability
- **Phase 2:** Enhanced user experience with real-time feedback  
- **Phase 3:** Comprehensive data collection via AI enhancement
- **Phase 4:** Professional-grade legal compliance system

---

## 📋 Progressive Data Collection Strategy

### Real-Time Organization Profiling (Phase 1)

#### Step 1: Core Organization Identity
**UI Components**: Basic form fields with immediate validation
```elixir
# Core fields with instant impact on screening
- organization_name (string) → Entity verification
- organization_type (enum) → Legal framework selection  
- headquarters_region (enum) → Geographic jurisdiction
- registration_number (string) → Official entity validation
```
**Real-Time Screening**: Geographic filtering, legal entity type validation
**Immediate Feedback**: "Based in England - 1,247 potential regulations apply"

#### Step 2: Organization Size & Scale  
**UI Components**: Number inputs with threshold indicators
```elixir
# Size-based regulatory triggers
- total_employees (integer) → Threshold-based obligations
- annual_turnover (integer) → Financial regulation triggers
- operational_extent (enum) → Multi-jurisdiction analysis
```
**Real-Time Screening**: Employee thresholds (5+, 50+, 250+), turnover-based regulations
**Immediate Feedback**: "50+ employees: Additional consultation requirements apply"

#### Step 3: Primary Business Sector
**UI Components**: SIC code lookup with autocomplete
```elixir
# Sector-specific regulation identification
- primary_sic_code (string) → Direct family field mapping
- industry_sector (enum) → High-level categorization
- business_activities (string[]) → Activity-specific triggers
```
**Real-Time Screening**: Family field matching, sector-specific regulation filtering
**Immediate Feedback**: "Construction sector: 89 safety regulations identified"

#### Step 4: Geographic & Operational Scope
**UI Components**: Multi-select with map visualization
```elixir
# Geographic applicability refinement
- operational_regions (string[]) → Regional law variations
- international_operations (boolean) → Cross-border obligations
- public_sector_contracts (boolean) → Procurement law triggers
```
**Real-Time Screening**: Geographic extent filtering, jurisdiction-specific laws
**Immediate Feedback**: "Operations in Wales: Additional Welsh language requirements"

### AI-Enhanced Deep Profiling (Phase 2)

#### Intelligent Question Generation Strategy
Based on Phase 1 data, AI generates targeted questions using organization schema:

**Construction + 50+ employees + England = AI Questions:**
```
"I can see you're a construction company with 50+ employees in England. 
To provide the most accurate compliance guidance, I need to understand:

1. Do you work at height or in confined spaces? [Safety Regulations]
2. Do you handle hazardous substances like asbestos or chemicals? [COSHH Compliance]  
3. Who is your appointed health & safety officer? [Duty Holder Identification]
4. Do you use subcontractors or agency workers? [Contractor Obligations]
5. What types of construction projects do you undertake? [Activity-Specific Rules]"
```

**Healthcare + Charity + Data Processing = AI Questions:**
```
"As a healthcare charity processing personal data, I need to confirm:

1. Do you provide direct patient care? [Clinical Governance]
2. What types of personal data do you process? [GDPR Compliance]
3. Do you have a Data Protection Officer appointed? [DPO Requirements]
4. Do you handle vulnerable adults or children? [Safeguarding Duties]
5. Are you registered with the Care Quality Commission? [Regulatory Oversight]"
```

#### Dynamic Schema Field Prioritization
AI prioritizes organization schema fields based on:
- **Regulatory Impact Scoring**: Fields that trigger the most regulations
- **Compliance Risk Assessment**: High-risk activities get priority
- **Sector-Specific Requirements**: Industry-standard obligations
- **Size-Based Thresholds**: Critical employee/turnover triggers

### AI Handover & Enhancement Strategy

#### Handover Trigger Points
The system transitions from basic UI to AI enhancement when:
```elixir
# Handover conditions
def ready_for_ai_enhancement?(organization_profile) do
  has_core_data = [:organization_name, :organization_type, :headquarters_region] 
                  |> Enum.all?(&Map.has_key?(organization_profile, &1))
                  
  has_size_data = [:total_employees, :annual_turnover] 
                  |> Enum.any?(&Map.has_key?(organization_profile, &1))
                  
  has_sector_data = [:primary_sic_code, :industry_sector] 
                    |> Enum.any?(&Map.has_key?(organization_profile, &1))
                    
  base_matches = get_basic_regulation_matches(organization_profile)
  
  has_core_data && has_size_data && has_sector_data && length(base_matches) > 10
end
```

#### AI Analysis Framework
When basic data collection is complete, AI performs gap analysis:

**1. Profile Completeness Assessment**
```elixir
def analyze_profile_gaps(organization_profile, sector) do
  # Identify critical missing schema fields for this sector
  sector_critical_fields = get_sector_critical_fields(sector)
  missing_fields = sector_critical_fields -- Map.keys(organization_profile)
  
  # Prioritize missing fields by regulatory impact
  prioritized_gaps = Enum.sort_by(missing_fields, &field_impact_score(&1, sector), :desc)
  
  # Generate targeted questions for top gaps
  generate_questions_for_fields(prioritized_gaps, organization_profile)
end
```

**2. Sector-Specific Question Generation**
```elixir
# Example: Construction sector gap analysis
construction_critical_fields = [
  :height_work,           # Working at height regulations
  :hazardous_substances,  # COSHH compliance  
  :manual_handling,       # Manual handling regulations
  :safety_representatives,# Safety rep requirements
  :subcontractors        # Contractor management
]

# Generate contextual questions
"Based on your construction business with 50+ employees, I need to understand 
your specific activities to identify all applicable health & safety requirements:

1. Do you undertake work at height (scaffolding, roofing, etc.)? 
   → Triggers Working at Height Regulations 2005

2. Do you handle hazardous substances like asbestos, lead paint, or chemicals?
   → Triggers COSHH regulations and specific substance controls

3. Who is your appointed health & safety officer or competent person?
   → Required under Management of Health & Safety at Work Regulations"
```

**3. Intelligent Follow-Up Strategy**
```elixir
def generate_follow_up_questions(current_answers, organization_profile) do
  case current_answers do
    %{height_work: true} ->
      # Drill down into height work specifics
      ["What types of height work do you perform?",
       "Do you use scaffolding, ladders, or mobile platforms?",
       "What is the maximum height you typically work at?"]
       
    %{hazardous_substances: true} ->
      # Drill down into substance types
      ["What types of hazardous substances do you handle?",
       "Do you work with asbestos-containing materials?", 
       "Do you have COSHH assessments in place?"]
       
    %{subcontractors: true} ->
      # Explore contractor relationships
      ["How many subcontractors do you typically use?",
       "Do they bring their own equipment and materials?",
       "Who manages health & safety coordination on multi-contractor sites?"]
  end
end
```

#### AI-to-Schema Mapping Process
```elixir
def map_ai_responses_to_schema(ai_conversation, existing_profile) do
  # Extract structured data from conversational responses
  extracted_data = extract_entities_from_conversation(ai_conversation)
  
  # Map to organization schema fields
  schema_updates = %{
    height_work: extract_boolean(extracted_data, "height work"),
    hazardous_substances: extract_substance_list(extracted_data),
    safety_management_system: extract_boolean(extracted_data, "safety management"),
    appointed_competent_persons: extract_competent_persons(extracted_data),
    risk_assessment_frequency: extract_frequency(extracted_data, "risk assessment")
  }
  
  # Merge with existing profile
  Map.merge(existing_profile, schema_updates)
end
```

---

## 💾 Organization Persistence Strategy

### Domain-Based Organization Sharing
Organizations are shared across users with the same email domain to enable collaborative compliance management within companies.

#### Organization Identity & Sharing Model
```elixir
defmodule Sertantai.Organizations.Organization do
  use Ash.Resource
  
  attributes do
    # Primary identification
    uuid_primary_key :id
    attribute :email_domain, :string, allow_nil?: false
    attribute :organization_name, :string, allow_nil?: false
    attribute :verified, :boolean, default: false
    
    # Core mandatory fields (from organization schema)
    attribute :core_profile, :map, allow_nil?: false, default: %{}
    
    # Dynamic AI-discovered fields (flexible JSON structure)
    attribute :extended_profile, :map, allow_nil?: false, default: %{}
    
    # Metadata
    attribute :created_by_user_id, :uuid, allow_nil?: false
    attribute :last_updated_by_user_id, :uuid, allow_nil?: false
    attribute :profile_completeness_score, :decimal, default: 0.0
    
    timestamps()
  end
  
  relationships do
    belongs_to :created_by, Sertantai.Accounts.User
    belongs_to :last_updated_by, Sertantai.Accounts.User
    has_many :organization_users, Sertantai.Organizations.OrganizationUser
    has_many :users, Sertantai.Accounts.User do
      source_attribute :id
      destination_attribute :organization_id
      through :organization_users
    end
  end
end
```

#### User-Organization Relationship
```elixir
defmodule Sertantai.Organizations.OrganizationUser do
  use Ash.Resource
  
  attributes do
    uuid_primary_key :id
    attribute :role, :atom, constraints: [one_of: [:owner, :admin, :member, :viewer]]
    attribute :joined_at, :utc_datetime, default: &DateTime.utc_now/0
    attribute :permissions, :map, default: %{}
  end
  
  relationships do
    belongs_to :organization, Sertantai.Organizations.Organization
    belongs_to :user, Sertantai.Accounts.User
  end
end
```

### Dynamic JSON Schema Structure

#### Core Profile (Mandatory Fields)
```json
{
  "core_profile": {
    "organization_name": "ACME Construction Ltd",
    "organization_type": "limited_company",
    "registration_number": "12345678",
    "headquarters_region": "england",
    "total_employees": 75,
    "annual_turnover": 5000000,
    "primary_sic_code": "41201",
    "industry_sector": "construction",
    "operational_extent": "england_and_wales",
    "operational_regions": ["england", "wales"],
    "created_at": "2024-01-15T10:30:00Z",
    "last_updated_at": "2024-01-20T14:45:00Z"
  }
}
```

#### Extended Profile (Dynamic AI Fields)  
```json
{
  "extended_profile": {
    "health_safety": {
      "height_work": true,
      "confined_spaces": false,
      "hazardous_substances": ["asbestos", "lead_paint"],
      "safety_management_system": true,
      "appointed_safety_officer": {
        "name": "John Smith",
        "qualifications": ["NEBOSH", "IOSH"]
      },
      "risk_assessment_frequency": "monthly",
      "accident_reporting_system": true,
      "ai_discovered_at": "2024-01-20T15:30:00Z"
    },
    "environmental": {
      "waste_production": "medium",
      "waste_types": ["construction_demolition", "hazardous"],
      "environmental_permits": ["waste_carrier"],
      "emissions_to_air": false,
      "ai_discovered_at": "2024-01-20T15:45:00Z"
    },
    "employment": {
      "has_young_workers": false,
      "has_night_workers": true,
      "collective_bargaining": true,
      "recognized_unions": ["UNITE"],
      "flexible_working_policy": true,
      "ai_discovered_at": "2024-01-20T16:00:00Z"
    },
    "ai_conversation_history": [
      {
        "session_id": "conv_001",
        "timestamp": "2024-01-20T15:30:00Z",
        "questions_asked": 12,
        "fields_discovered": ["height_work", "safety_officer", "risk_assessment_frequency"],
        "completeness_improvement": 0.15
      }
    ]
  }
}
```

### Organization Discovery & Auto-Assignment

#### Email Domain Matching
```elixir
defmodule Sertantai.Organizations.OrganizationService do
  def find_or_create_organization_for_user(user) do
    email_domain = extract_domain(user.email)
    
    case find_organization_by_domain(email_domain) do
      {:ok, organization} -> 
        # Add user to existing organization
        add_user_to_organization(user, organization)
        {:ok, organization}
        
      {:error, :not_found} ->
        # Create new organization for this domain
        create_organization_for_domain(email_domain, user)
    end
  end
  
  defp extract_domain(email) do
    email 
    |> String.split("@") 
    |> List.last() 
    |> String.downcase()
  end
  
  defp find_organization_by_domain(domain) do
    Organization
    |> Ash.Query.filter(email_domain == ^domain)
    |> Ash.read_one()
  end
end
```

#### Special Domain Handling
```elixir
# Handle common email providers vs. company domains
def is_company_domain?(domain) do
  consumer_domains = [
    "gmail.com", "hotmail.com", "outlook.com", "yahoo.com", 
    "aol.com", "icloud.com", "live.com", "msn.com"
  ]
  
  domain not in consumer_domains
end

def handle_consumer_email_domain(user) do
  # For consumer emails, create individual organization
  # or prompt user to enter company email
  case user.organization_manually_entered do
    nil -> prompt_for_company_email_or_manual_org()
    org_name -> create_individual_organization(user, org_name)
  end
end
```

### Profile Completeness & Validation

#### Completeness Scoring Algorithm
```elixir
def calculate_profile_completeness(organization) do
  core_score = calculate_core_completeness(organization.core_profile)
  extended_score = calculate_extended_completeness(organization.extended_profile)
  sector_specific_score = calculate_sector_completeness(organization)
  
  # Weighted scoring: core 60%, extended 30%, sector-specific 10%
  total_score = (core_score * 0.6) + (extended_score * 0.3) + (sector_specific_score * 0.1)
  
  %{
    total: total_score,
    core: core_score,
    extended: extended_score,
    sector_specific: sector_specific_score,
    next_recommendations: get_completion_recommendations(organization)
  }
end

def calculate_core_completeness(core_profile) do
  required_fields = [
    :organization_name, :organization_type, :headquarters_region,
    :total_employees, :primary_sic_code, :operational_extent
  ]
  
  completed_fields = Enum.count(required_fields, &Map.has_key?(core_profile, &1))
  completed_fields / length(required_fields)
end
```

#### Sector-Specific Field Requirements
```elixir
def get_sector_required_fields(sector) do
  case sector do
    "construction" -> [
      "health_safety.height_work",
      "health_safety.hazardous_substances", 
      "health_safety.appointed_safety_officer",
      "employment.subcontractors"
    ]
    
    "healthcare" -> [
      "employment.has_night_workers",
      "health_safety.biological_agents",
      "compliance.regulatory_approvals",
      "data_processing.data_protection_officer"
    ]
    
    "manufacturing" -> [
      "health_safety.uses_machinery",
      "environmental.emissions_to_air",
      "health_safety.noise_exposure",
      "environmental.waste_production"
    ]
  end
end
```

### Integration with UserSelections System

#### Enhanced UserSelections for Organizations
```elixir
# Extend existing UserSelections to link with organization profiles
defmodule Sertantai.UserSelections do
  # Add organization-aware selection storage
  def store_organization_selections(organization_id, selected_ids, opts \\ []) do
    # Store selections linked to organization rather than just user
    # This enables organization-wide compliance tracking
    
    timestamp = DateTime.utc_now()
    organization_key = "org:#{organization_id}"
    
    :ets.insert(@table_name, {organization_key, selected_ids, timestamp})
    
    # Also store organization profile metadata with selections
    if Keyword.get(opts, :store_profile_context, true) do
      organization = get_organization(organization_id)
      profile_context = extract_selection_context(organization)
      store_selection_context(organization_key, profile_context)
    end
    
    :ok
  end
  
  def get_organization_selections(organization_id) do
    organization_key = "org:#{organization_id}"
    case :ets.lookup(@table_name, organization_key) do
      [{^organization_key, selected_ids, _timestamp}] -> selected_ids
      [] -> load_organization_selections_from_database(organization_id)
    end
  end
end
```

#### Organization-Regulation Matching Context
```elixir
def store_selection_context(organization_key, profile_context) do
  context_data = %{
    sector: profile_context.primary_sic_code,
    size_category: categorize_organization_size(profile_context),
    risk_profile: extract_risk_indicators(profile_context),
    geographic_scope: profile_context.operational_extent,
    ai_enhancement_level: profile_context.completeness_score
  }
  
  :ets.insert(:selection_context, {organization_key, context_data, DateTime.utc_now()})
end
```

### Migration & Data Management

#### Handling Profile Evolution
```elixir
# As AI discovers new organization attributes, gracefully extend the profile
def extend_organization_profile(organization_id, new_attributes, ai_session_info) do
  organization = get_organization!(organization_id)
  
  updated_extended_profile = 
    organization.extended_profile
    |> deep_merge(new_attributes)
    |> add_ai_discovery_metadata(ai_session_info)
  
  organization
  |> Ash.Changeset.for_update(:update, %{
      extended_profile: updated_extended_profile,
      profile_completeness_score: calculate_profile_completeness(organization).total
     })
  |> Ash.update()
end

defp add_ai_discovery_metadata(profile, ai_session_info) do
  # Add metadata about when and how each field was discovered
  discovery_metadata = %{
    discovered_at: DateTime.utc_now(),
    ai_session_id: ai_session_info.session_id,
    confidence_score: ai_session_info.confidence,
    discovery_method: ai_session_info.method  # "conversation", "inference", "validation"
  }
  
  put_in(profile, [:_metadata, :ai_discovery], discovery_metadata)
end
```

---

## 🔄 Organization Similarity & Law Profile Acceleration

### Confidentiality-Preserving Organization Matching
Leverage existing organization-law profiles to accelerate new user onboarding while maintaining strict data confidentiality.

#### Organization Similarity Scoring Algorithm
```elixir
defmodule Sertantai.Organizations.SimilarityMatcher do
  @doc """
  Find similar organizations based on key matching criteria without exposing confidential data.
  Returns anonymized law profiles for AI context, not organization details.
  """
  def find_similar_organizations(new_organization) do
    # Define similarity matching criteria (non-confidential attributes)
    matching_criteria = %{
      primary_sic_code: new_organization.core_profile.primary_sic_code,
      industry_sector: new_organization.core_profile.industry_sector,
      size_category: categorize_size(new_organization.core_profile.total_employees),
      operational_extent: new_organization.core_profile.operational_extent,
      organization_type: new_organization.core_profile.organization_type
    }
    
    # Find organizations with similar profiles (exclude same domain for privacy)
    similar_orgs = Organization
    |> where([o], o.email_domain != ^new_organization.email_domain)
    |> where([o], fragment("?->>'primary_sic_code' = ?", o.core_profile, ^matching_criteria.primary_sic_code))
    |> where([o], fragment("?->>'operational_extent' = ?", o.core_profile, ^matching_criteria.operational_extent))
    |> where([o], o.profile_completeness_score > 0.7)  # Only well-profiled organizations
    |> Ash.read!()
    
    # Calculate similarity scores and return anonymized law profiles
    Enum.map(similar_orgs, &calculate_similarity_score(&1, matching_criteria))
    |> Enum.filter(&(&1.similarity_score > 0.8))
    |> Enum.sort_by(&(&1.similarity_score), :desc)
    |> Enum.take(3)  # Top 3 matches
    |> Enum.map(&extract_anonymized_law_profile/1)
  end
  
  defp calculate_similarity_score(organization, criteria) do
    scores = %{
      sic_exact: exact_match_score(organization.core_profile["primary_sic_code"], criteria.primary_sic_code),
      sector: exact_match_score(organization.core_profile["industry_sector"], criteria.industry_sector),
      size: size_similarity_score(organization.core_profile["total_employees"], criteria.size_category),
      geography: exact_match_score(organization.core_profile["operational_extent"], criteria.operational_extent),
      org_type: exact_match_score(organization.core_profile["organization_type"], criteria.organization_type)
    }
    
    # Weighted similarity calculation
    similarity_score = 
      scores.sic_exact * 0.35 +      # SIC code is most important
      scores.sector * 0.25 +         # Industry sector
      scores.size * 0.20 +           # Organization size
      scores.geography * 0.15 +      # Geographic scope
      scores.org_type * 0.05         # Organization type
    
    %{
      organization_id: organization.id,
      similarity_score: similarity_score,
      matching_attributes: scores,
      anonymized_profile: anonymize_profile(organization)
    }
  end
end
```

#### Anonymized Law Profile Extraction
```elixir
def extract_anonymized_law_profile(similarity_match) do
  organization = get_organization!(similarity_match.organization_id)
  
  # Get organization's applicable law selections (without exposing organization details)
  applicable_laws = get_organization_selections(organization.id)
  law_categories = categorize_applicable_laws(applicable_laws)
  
  %{
    similarity_score: similarity_match.similarity_score,
    anonymized_attributes: %{
      # Safe to share - no confidential information
      sector: organization.core_profile["industry_sector"],
      size_category: categorize_size(organization.core_profile["total_employees"]),
      geographic_scope: organization.core_profile["operational_extent"],
      risk_indicators: extract_risk_indicators(organization.extended_profile),
      activity_profile: extract_activity_indicators(organization.extended_profile)
    },
    applicable_law_profile: %{
      total_applicable_laws: length(applicable_laws),
      law_categories: law_categories,
      high_priority_laws: extract_high_priority_laws(applicable_laws),
      sector_specific_laws: extract_sector_laws(applicable_laws, organization.core_profile["industry_sector"]),
      size_threshold_laws: extract_size_based_laws(applicable_laws, organization.core_profile["total_employees"])
    },
    profile_completeness: organization.profile_completeness_score,
    last_ai_enhancement: get_last_ai_session_date(organization)
  }
end

defp anonymize_profile(organization) do
  # Return only non-confidential, aggregated profile indicators
  %{
    has_safety_management_system: has_field?(organization.extended_profile, "health_safety.safety_management_system"),
    has_environmental_permits: has_field?(organization.extended_profile, "environmental.environmental_permits"),
    has_appointed_officers: has_field?(organization.extended_profile, "health_safety.appointed_safety_officer"),
    works_with_hazardous_materials: has_field?(organization.extended_profile, "health_safety.hazardous_substances"),
    uses_subcontractors: has_field?(organization.extended_profile, "employment.subcontractors"),
    # ... other boolean indicators that don't reveal specific company details
  }
end
```

### AI Context Enhancement Using Similar Organizations

#### Smart Question Prioritization
```elixir
def enhance_ai_questions_with_similar_profiles(new_organization, similar_law_profiles) do
  base_questions = generate_base_questions(new_organization)
  
  # Analyze similar organizations to prioritize questions
  prioritized_questions = similar_law_profiles
  |> extract_common_critical_fields()
  |> cross_reference_with_base_questions(base_questions)
  |> sort_by_regulatory_impact()
  
  # Generate AI context with anonymized insights
  ai_context = """
  I'm analyzing a #{new_organization.core_profile.industry_sector} organization with 
  #{categorize_size(new_organization.core_profile.total_employees)} employees in 
  #{new_organization.core_profile.operational_extent}.
  
  Based on #{length(similar_law_profiles)} similar organizations in our system:
  
  Common Critical Requirements:
  #{format_common_requirements(similar_law_profiles)}
  
  Typical Law Categories for This Profile:
  #{format_typical_law_categories(similar_law_profiles)}
  
  High-Impact Questions to Ask:
  #{format_prioritized_questions(prioritized_questions)}
  """
  
  {prioritized_questions, ai_context}
end

defp extract_common_critical_fields(similar_profiles) do
  # Find fields that appear in 80%+ of similar organizations
  all_fields = Enum.flat_map(similar_profiles, &extract_discovered_fields/1)
  field_frequencies = Enum.frequencies(all_fields)
  threshold = length(similar_profiles) * 0.8
  
  field_frequencies
  |> Enum.filter(fn {_field, count} -> count >= threshold end)
  |> Enum.map(fn {field, _count} -> field end)
  |> Enum.sort_by(&get_field_regulatory_impact/1, :desc)
end
```

#### Law Profile Context for AI Prompting
```elixir
def generate_ai_context_from_similar_orgs(similar_law_profiles, new_organization) do
  context = """
  ORGANIZATION CONTEXT:
  New organization: #{new_organization.core_profile.industry_sector} sector, 
  #{new_organization.core_profile.total_employees} employees, #{new_organization.core_profile.operational_extent}
  
  SIMILAR ORGANIZATION INSIGHTS (anonymized data):
  #{format_similar_org_insights(similar_law_profiles)}
  
  COMMON LAW PATTERNS:
  - Organizations like this typically have #{avg_law_count(similar_law_profiles)} applicable regulations
  - #{get_most_common_law_categories(similar_law_profiles)}
  - Critical compliance areas: #{get_critical_compliance_areas(similar_law_profiles)}
  
  RECOMMENDED QUESTIONING STRATEGY:
  Based on similar organizations, prioritize questions about:
  1. #{get_top_priority_area(similar_law_profiles, 1)}
  2. #{get_top_priority_area(similar_law_profiles, 2)}
  3. #{get_top_priority_area(similar_law_profiles, 3)}
  
  Focus on gaps that could trigger significant regulatory obligations.
  """
  
  context
end

defp format_similar_org_insights(profiles) do
  profiles
  |> Enum.with_index(1)
  |> Enum.map(fn {profile, index} ->
    """
    Similar Org #{index} (#{Float.round(profile.similarity_score * 100)}% match):
    - #{profile.applicable_law_profile.total_applicable_laws} applicable laws
    - Key areas: #{Enum.join(Map.keys(profile.applicable_law_profile.law_categories), ", ")}
    - Risk profile: #{describe_risk_profile(profile.anonymized_attributes.risk_indicators)}
    """
  end)
  |> Enum.join("\n")
end
```

### Acceleration Strategies

#### Smart Onboarding Flow
```elixir
def accelerate_onboarding_with_similar_profiles(new_organization) do
  similar_profiles = find_similar_organizations(new_organization)
  
  case similar_profiles do
    [] -> 
      # No similar organizations - standard onboarding
      standard_ai_onboarding(new_organization)
      
    [high_match | _] when high_match.similarity_score > 0.95 ->
      # Very high similarity - fast-track with targeted questions
      fast_track_onboarding(new_organization, high_match)
      
    similar_profiles ->
      # Multiple similar profiles - enhanced context
      enhanced_onboarding(new_organization, similar_profiles)
  end
end

def fast_track_onboarding(new_organization, high_match_profile) do
  # Skip basic questions, focus on organization-specific differences
  ai_prompt = """
  This organization is very similar to existing organizations in our system (#{Float.round(high_match_profile.similarity_score * 100)}% match).
  
  Similar organizations typically need to comply with #{high_match_profile.applicable_law_profile.total_applicable_laws} regulations in areas like:
  #{format_law_categories(high_match_profile.applicable_law_profile.law_categories)}
  
  Instead of asking all basic questions, focus on:
  1. Confirming key assumptions about their activities
  2. Identifying any unique aspects that might change their obligations
  3. Validating the most critical compliance requirements
  
  Start with: "Based on similar organizations, you'll likely need to comply with regulations in [X areas]. 
  Let me confirm a few key details to ensure we identify all your specific obligations..."
  """
  
  generate_targeted_questions(new_organization, high_match_profile, ai_prompt)
end
```

#### Regulation Pre-Loading Strategy
```elixir
def preload_likely_applicable_laws(new_organization, similar_profiles) do
  # Extract common law patterns from similar organizations
  common_laws = similar_profiles
  |> Enum.flat_map(&(&1.applicable_law_profile.high_priority_laws))
  |> Enum.frequencies()
  |> Enum.filter(fn {_law, count} -> count >= length(similar_profiles) * 0.6 end)
  |> Enum.map(fn {law, _count} -> law end)
  
  # Pre-populate likely applicable laws for faster AI context
  preloaded_context = %{
    likely_applicable_laws: common_laws,
    confidence_indicators: %{
      sector_match: get_sector_confidence(new_organization, similar_profiles),
      size_match: get_size_confidence(new_organization, similar_profiles),
      activity_match: get_activity_confidence(new_organization, similar_profiles)
    },
    areas_to_validate: extract_validation_priorities(similar_profiles),
    skip_basic_questions: extract_confirmed_assumptions(similar_profiles)
  }
  
  preloaded_context
end
```

### Privacy & Security Safeguards

#### Data Protection Measures
```elixir
def ensure_confidentiality_compliance(similarity_matching_process) do
  safeguards = [
    # 1. No organization names or identifying details shared
    :anonymize_all_identifying_data,
    
    # 2. Only aggregate patterns and law categories shared
    :share_only_regulatory_patterns,
    
    # 3. Exclude organizations from same domain/competitors
    :exclude_related_organizations,
    
    # 4. Minimum similarity threshold to prevent broad matching
    :require_high_similarity_score,
    
    # 5. Audit trail of what context was shared
    :log_shared_context_for_audit,
    
    # 6. User consent for anonymized pattern matching
    :obtain_user_consent_for_matching
  ]
  
  validate_safeguards(similarity_matching_process, safeguards)
end

def audit_context_sharing(new_organization_id, shared_context) do
  AuditLog.create(%{
    organization_id: new_organization_id,
    action: "similarity_context_used",
    anonymized_context_shared: shared_context,
    source_organizations: "anonymized_similar_profiles",
    privacy_safeguards_applied: true,
    timestamp: DateTime.utc_now()
  })
end
```

---

## 🚀 Schema-Enhanced Implementation Plan

### Phase 1: Real-Time Basic Screening Implementation
- **Phoenix LiveView Forms**: Real-time organization data capture with instant feedback
- **Progressive Query Building**: Each field entry refines database queries
  ```elixir
  # Step-by-step query refinement
  base_query = UkLrt |> where([u], u.live == "✔ In force")
  
  # Add geographic filtering as user selects region
  |> where([u], fragment("? ?| ?", u.geo_extent, ^user_regions))
  
  # Add sector filtering when SIC code entered  
  |> where([u], u.family in ^mapped_family_codes)
  
  # Add size-based thresholds when employee count entered
  |> where([u], fragment("employee_threshold_applies(?, ?)", u.duty_holder, ^employee_count))
  ```
- **Immediate Feedback System**: Live counters, threshold notifications, sector matches

### Phase 3: AI-Enhanced Deep Screening Implementation  
- **Context-Aware Question Generation**: AshAI analyzes basic profile via Ash actions
- **Organization Schema Integration**: Type-safe mapping via Ash attribute validation
- **Native AI Processing**: In-process AI analysis using AshAI framework

### Phase 3: Comprehensive Results & Persistence
- **Enhanced UserSelections**: Store complete organization profile + regulation matches
- **Confidence Scoring**: Multi-factor scoring based on field alignment strength
- **Explanation Generation**: AI-generated reasoning for each regulation match

### Phase 4: Progressive Query Examples
```elixir
# Construction site safety for Site Managers in England
UkLrt
|> where([u], u.family == "💙 CONSTRUCTION")
|> where([u], u.live == "✔ In force") 
|> where([u], fragment("? @> ?", u.duty_holder, ["Site Manager"]))
|> where([u], fragment("? ?| ?", u.geo_extent, ["England", "England and Wales"]))

# Fire safety for Employers across UK
UkLrt  
|> where([u], u.family == "💙 FIRE")
|> where([u], fragment("? @> ?", u.duty_holder, ["Employer"]))
|> where([u], u.live == "✔ In force")
|> order_by([u], desc: u.latest_amend_date)
```

---

## 👥 Stakeholder Matching Algorithms

### JSONB Role Field Strategy
The schema provides rich stakeholder data through multiple JSONB arrays that enable sophisticated role-based matching:

#### Core Role Fields
- **`role`**: General roles/duties (e.g., ["Manager", "Employee", "Occupier"])
- **`duty_holder`**: Specific entities with legal duties (e.g., ["Employer", "Site Manager", "Principal Contractor"])
- **`power_holder`**: Entities granted regulatory powers (e.g., ["Inspector", "Local Authority", "Secretary of State"])
- **`rights_holder`**: Entities with specific rights (e.g., ["Employee", "Tenant", "Consumer"])
- **`responsibility_holder`**: Entities with broader responsibilities (e.g., ["Organization", "Public Body"])

#### Matching Algorithm Approaches

**1. Exact Match Algorithm**
```elixir
def exact_role_match(user_role, uk_lrt_record) do
  role_fields = [:duty_holder, :role, :power_holder, :rights_holder, :responsibility_holder]
  
  Enum.any?(role_fields, fn field ->
    field_value = Map.get(uk_lrt_record, field, [])
    user_role in field_value
  end)
end
```

**2. Hierarchical Role Matching**
```elixir
# Define role hierarchies for intelligent matching
role_hierarchies = %{
  "Site Manager" => ["Manager", "Person in Control", "Supervisor"],
  "Principal Contractor" => ["Contractor", "Employer", "Organization"],
  "Health & Safety Officer" => ["Officer", "Professional", "Competent Person"]
}

def hierarchical_role_match(user_role, uk_lrt_record, hierarchies) do
  expanded_roles = [user_role | Map.get(hierarchies, user_role, [])]
  
  role_fields = [:duty_holder, :role, :power_holder, :rights_holder]
  
  Enum.any?(role_fields, fn field ->
    field_value = Map.get(uk_lrt_record, field, [])
    Enum.any?(expanded_roles, &(&1 in field_value))
  end)
end
```

**3. Semantic Role Matching (AI-Enhanced)**
```elixir
def semantic_role_match(user_role, user_context, uk_lrt_record) do
  # Use AshAI for LLM-based role similarity with type safety
  Sertantai.AI.RoleAnalysis.analyze_role_match!(
    user_role: user_role,
    user_context: user_context,
    duty_holders: uk_lrt_record.duty_holder,
    general_roles: uk_lrt_record.role,
    power_holders: uk_lrt_record.power_holder
  )
end
```

#### Multi-Dimensional Matching Matrix

| User Input | Primary Match Field | Secondary Fields | Algorithm |
|------------|--------------------|--------------------|-----------|
| "Site Manager" | `duty_holder` | `role`, `responsibility_holder` | Exact + Hierarchical |
| "Employer" | `duty_holder` | `power_holder`, `responsibility_holder` | Exact + Legal Context |
| "Inspector" | `power_holder` | `role` | Exact + Authority Level |
| "Employee" | `rights_holder` | `role`, `duty_holder` | Hierarchical + Context |
| "Organization" | `responsibility_holder` | `duty_holder`, `power_holder` | Entity Type + Size |

#### Geographic + Role Compound Matching
```elixir
def compound_applicability_score(user_profile, uk_lrt_record) do
  scores = %{
    sector: sector_match_score(user_profile.sector, uk_lrt_record.family),
    role: role_match_score(user_profile.role, uk_lrt_record),
    geography: geo_match_score(user_profile.location, uk_lrt_record.geo_extent),
    status: status_match_score(uk_lrt_record.live),
    content: semantic_match_score(user_profile.activities, uk_lrt_record.md_description)
  }
  
  # Weighted composite score
  weighted_score = 
    scores.sector * 0.3 +
    scores.role * 0.25 +
    scores.geography * 0.2 +
    scores.status * 0.15 +
    scores.content * 0.1
    
  {weighted_score, scores} # Return both composite and breakdown
end
```

---

## 🔍 Advanced Query Patterns

### Progressive Filtering Strategy
```elixir
def progressive_applicability_filter(user_profile) do
  UkLrt
  # Layer 1: Hard constraints (must match)
  |> where([u], u.live == "✔ In force")
  |> where([u], fragment("? ?| ?", u.geo_extent, ^user_profile.geographic_scope))
  
  # Layer 2: Sector relevance (primary filter)
  |> where([u], u.family in ^user_profile.relevant_sectors)
  
  # Layer 3: Role matching (JSONB queries)
  |> where([u], 
    fragment("? @> ?", u.duty_holder, [^user_profile.primary_role]) or
    fragment("? @> ?", u.role, ^user_profile.role_hierarchy) or
    fragment("? @> ?", u.responsibility_holder, ^user_profile.entity_types)
  )
  
  # Layer 4: Content relevance (optional semantic layer)
  |> where([u], fragment("? @@ to_tsquery(?)", u.md_description, ^user_profile.activity_keywords))
  
  # Ranking by relevance
  |> order_by([u], [
    desc: fragment("? <-> ?", u.family, ^user_profile.primary_sector),
    desc: u.latest_amend_date
  ])
end
```

---

## 🔍 **Critical Implementation Review & Phase Restructure**

*Added: January 2025 - Critical analysis of development phases and missing elements*  
*Updated: January 2025 - Issues addressed in main document restructure*

### ✅ **Resolved Issues**

The following critical issues identified in the original review have been addressed in the main document:

#### **Phase Structure Fixed**
- ✅ **Clear 4-phase structure** with distinct boundaries and dependencies
- ✅ **Self-contained deliverables** for each phase with measurable success criteria
- ✅ **Technology separation** - no AI components until Phase 3
- ✅ **Progressive complexity** from basic queries to advanced AI analysis

#### **Success Criteria & Deliverables Added**
- ✅ **Specific success metrics** for each phase (response times, accuracy, completion rates)
- ✅ **Clear deliverables** with checkboxes for tracking progress
- ✅ **Performance benchmarks** defined (2s queries, 500ms real-time, 90% accuracy)
- ✅ **User acceptance criteria** with measurable targets

#### **Missing Elements Now Included**
- ✅ **Legal Compliance Framework** - disclaimers, review workflows, audit trails
- ✅ **Data Quality Assurance** - validation, monitoring, Companies House integration
- ✅ **Performance & Reliability** - indexing, caching, graceful degradation
- ✅ **Regulation Change Management** - versioning, impact analysis, update workflows

#### **Implementation Risks Mitigated**
- ✅ **Phase dependencies clearly mapped** preventing technology mixing
- ✅ **Fallback strategies defined** for AI service failures
- ✅ **Database optimization strategy** for JSONB performance at scale
- ✅ **Legal validation workflow** integrated before production deployment

### 📋 **Implementation Readiness Summary**

The restructured document now provides a comprehensive, implementable roadmap with:

#### **Clear Development Path**
- **4 distinct phases** with specific technical scopes and dependencies
- **Progressive complexity** from basic database queries to AI-enhanced analysis
- **Self-contained deliverables** enabling incremental development and testing
- **Measurable success criteria** for each phase

#### **Production-Ready Framework**
- **Legal compliance system** with disclaimers, review workflows, and audit trails
- **Data quality assurance** including validation, monitoring, and change management  
- **Performance optimization** with indexing, caching, and scalability planning
- **Risk mitigation** through fallback mechanisms and graceful degradation

#### **Professional Standards**
- **Legal review integration** ensuring professional validation of AI advice
- **Comprehensive monitoring** for performance, accuracy, and compliance
- **User experience optimization** with clear error handling and edge case support
- **Audit trails and documentation** for regulatory compliance and liability protection

### 🚀 **Next Steps for Implementation**

1. **Phase 1 Foundation** - Start with basic organization schema and simple matching
2. **Legal Framework Setup** - Implement disclaimer and audit systems early
3. **Database Optimization** - Establish indexing and caching before Phase 2
4. **Professional Validation** - Engage legal professionals for review workflow design
5. **Performance Baseline** - Establish monitoring and benchmarks from Phase 1

This restructured approach provides a realistic, implementable path to building a professional-grade AI-driven applicability screening system while maintaining legal compliance and technical excellence.

---

*This critical review identifies the key structural and technical challenges that must be addressed for successful implementation of the applicability screening system. Each phase now has clear boundaries, deliverables, and success criteria to ensure progressive, measurable development.*
