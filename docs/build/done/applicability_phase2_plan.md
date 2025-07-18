# Phase 2 Implementation Plan: Real-Time Progressive Screening

**Project:** AI-Driven Applicability Screening Agent  
**Phase:** 2 of 4 - Real-Time Progressive Screening  
**Duration:** 6-8 weeks  
**Complexity:** Medium  
**Dependencies:** Phase 1 complete  

---

## 🎯 Phase 2 Overview

### Goal
Transform the static Phase 1 organization profiling into a dynamic, real-time system that provides live feedback as users enter data, with enhanced database querying and performance optimization.

### Success Definition
Users experience immediate, live updates of applicable law counts as they fill out organization details, with response times under 500ms and support for complex queries including role matching and threshold-based filtering.

### Key Enhancements over Phase 1
- **Real-time updates** - Live law count updates via Phoenix LiveView
- **Progressive screening** - Results refine as user enters more data
- **Function-based filtering** - Query optimization using 'Making' function to filter only duty-creating laws
- **Enhanced queries** - JSONB array matching and threshold filtering
- **Performance optimization** - Caching, indexing, and function-aware monitoring
- **Advanced organization schema** - Extended attributes for deeper profiling

---

## 🏗️ Technical Architecture

### System Components Enhancement

```
Phase 2 Architecture (Building on Phase 1):

┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Real-Time Progressive Screening                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────┐    ┌─────────────────┐                │
│ │ Enhanced        │    │ Real-Time       │                │
│ │ Organization    │◄──►│ LiveView        │                │
│ │ Service         │    │ Updates         │                │
│ └─────────────────┘    └─────────────────┘                │
│          │                       │                         │
│          ▼                       ▼                         │
│ ┌─────────────────┐    ┌─────────────────┐                │
│ │ Progressive     │    │ Elixir-Native   │                │
│ │ Query Engine    │◄──►│ Cache Layer     │                │
│ └─────────────────┘    └─────────────────┘                │
│          │                       │                         │
│          ▼                       ▼                         │
│ ┌─────────────────────────────────────────┐                │
│ │ Optimized PostgreSQL + JSONB Indexes   │                │
│ └─────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### Core Technology Stack
- **Frontend:** Phoenix LiveView with real-time updates
- **Backend:** Enhanced Ash Framework actions and queries
- **Database:** PostgreSQL with JSONB indexing strategy
- **Caching:** Elixir-native multi-layer approach (Cachex + ETS + Phoenix.PubSub)
- **Monitoring:** Telemetry-based performance tracking

---

## 📋 Implementation Roadmap

### Week 1-2: Database Optimization & Enhanced Schema

#### Database Performance Foundation
- **Function-Aware JSONB Indexing Strategy**
  - **Critical**: Implement GIN index on `function` JSONB field with 'Making' filter for maximum performance
  - Implement GIN indexes for `duty_holder`, `role`, and `purpose` JSONB fields
  - Create composite indexes combining `function`, `family`, `geo_extent`, and `live` for optimal query performance
  - Add threshold-based partial indexes for employee counts
  - Performance test index effectiveness with realistic data volumes focusing on 'Making' function subset

- **Organization Schema Enhancement**
  - Extend `core_profile` JSONB with Phase 2 fields:
    - `operational_regions`, `annual_turnover`, `business_activities`
    - `compliance_requirements`, `risk_profile`, `special_circumstances`
  - Create Ash embedded resources for complex nested data
  - Implement validation logic for extended attributes

- **Elixir-Native Caching Architecture**
  - Set up Cachex for law count and screening result caching
  - Configure ETS tables for high-frequency temporary data
  - Implement Phoenix.PubSub for real-time cache invalidation
  - Establish TTL strategies based on organization characteristics

#### Key Ash Framework Applications
- Leverage **Ash calculations** for complex organization profile scoring
- Use **Ash aggregates** for real-time law counts and statistics
- Implement **Ash changes** for profile completeness tracking
- Apply **Ash policies** for data access control

### Week 3-4: Progressive Query Engine Development

#### Real-Time Query Architecture
- **Progressive Query Builder**
  - Develop query building logic that adapts to available organization data
  - Implement query complexity scoring to optimize performance
  - Create fallback strategies for incomplete organization profiles
  - Design query result diffing for efficient LiveView updates

- **Function-Optimized Matching Logic**
  - **Primary optimization**: Filter for Function JSONB contains 'Making' (duty-creating laws only)
  - JSONB array matching for role-based applicability within 'Making' subset
  - Threshold-based filtering (employee counts, turnover) applied after function filtering
  - Geographic scope matching with operational regions on pre-filtered dataset
  - Business activity to legal family mapping enhancement with massive performance gains

- **Performance Optimization**
  - Elixir-native query result caching with intelligent invalidation
  - Connection pooling optimization for concurrent users
  - Database query performance monitoring and alerting
  - Load testing framework for concurrent user scenarios

#### Key Ash Framework Applications
- Use **Ash Query preparations** for dynamic query building
- Implement **Ash Resource calculations** for live metrics
- Leverage **code interfaces** with filtering options for LiveView integration
- Apply **Ash domains** for proper service organization

### Week 5-6: Real-Time LiveView Implementation

#### Enhanced User Interface
- **Progressive Form Experience**
  - Multi-step form with live validation and feedback
  - Real-time law count updates as users type
  - Progress indicators and completion scoring
  - Intelligent field ordering based on impact on results

- **Live Update System**
  - Phoenix LiveView real-time updates for law counts
  - Debounced input handling to optimize database queries
  - Loading states and graceful error handling
  - Responsive design for mobile and desktop usage

- **Enhanced Results Display**
  - Live charts and visualizations of applicable laws
  - Categorized results by legal family and impact level
  - Drill-down capabilities for regulation details
  - Export functionality for results and reports

#### Key Ash Framework Applications
- Use **AshPhoenix.Form** for progressive form handling
- Implement **nested forms** for complex organization data
- Leverage **authorization functions** for conditional UI rendering
- Apply **AshPhoenix LiveView** patterns for real-time updates

### Week 7-8: Testing, Performance, & Production Readiness

#### Comprehensive Testing Strategy
- **Unit Testing**
  - Progressive query engine logic
  - JSONB matching and filtering algorithms
  - Cache invalidation and consistency
  - Organization profile validation and scoring

- **Integration Testing**
  - LiveView real-time update flows
  - Database performance under load
  - Cache layer effectiveness and consistency
  - Error handling and graceful degradation

- **Performance Testing**
  - Concurrent user load testing (target: 100+ users)
  - Database query performance validation (<2s for complex queries)
  - Real-time update latency testing (<500ms target)
  - Memory usage and resource optimization

#### Production Preparation
- **Monitoring & Alerting**
  - Database performance dashboards
  - Real-time user experience metrics
  - Error rate monitoring and alerting
  - Cache hit rate and effectiveness tracking

- **Documentation & Handover**
  - API documentation for Phase 3 integration
  - Performance tuning guide and recommendations
  - User experience guidelines and patterns
  - Database maintenance and optimization procedures

---

## 🎛️ Technical Implementation Details

### Database Strategy

#### Function-Optimized JSONB Indexing Approach
```sql
-- Critical function-based index for maximum performance optimization
CREATE INDEX CONCURRENTLY idx_uk_lrt_function_making ON uk_lrt USING gin(function) 
  WHERE function ? 'Making';

-- Essential indexes for Phase 2 performance on 'Making' subset
CREATE INDEX CONCURRENTLY idx_uk_lrt_duty_holder_gin ON uk_lrt USING gin(duty_holder);
CREATE INDEX CONCURRENTLY idx_uk_lrt_role_gin ON uk_lrt USING gin(role);
CREATE INDEX CONCURRENTLY idx_organizations_profile_gin ON organizations USING gin(core_profile);

-- Composite index optimized for function-first queries
CREATE INDEX CONCURRENTLY idx_uk_lrt_function_composite ON uk_lrt(family, geo_extent, live) 
  WHERE function ? 'Making';
```

#### Elixir-Native Caching Strategy
- **Level 1:** Cachex for law count and screening result caching (TTL: 2-4 hours)
- **Level 2:** ETS for high-frequency temporary data and session caching
- **Level 3:** LiveView assigns for session-specific caching
- **Invalidation:** Phoenix.PubSub for real-time cache invalidation on updates

### Function-Based Performance Optimization

#### Critical Database Insight: 'Making' Function Filter
The UK LRT database contains laws with different functions:
- **Enacting**: Laws that establish legal frameworks
- **Commencing**: Laws that bring other laws into effect  
- **Amending**: Laws that modify existing regulations
- **Revoking**: Laws that cancel previous regulations
- **Making**: Laws that create duties, responsibilities, and obligations

**Key Optimization**: Only laws with 'Making' function create actual compliance duties for organizations. This represents approximately 20-40% of the total dataset, providing massive performance improvements when used as the primary filter.

#### Query Strategy Impact
```sql
-- Before function optimization (scans all records)
SELECT COUNT(*) FROM uk_lrt 
WHERE live = '✔ In force' 
  AND family = 'CONSTRUCTION' 
  AND geo_extent IN ('England', 'Great Britain');

-- After function optimization (scans only duty-creating subset)  
SELECT COUNT(*) FROM uk_lrt 
WHERE function ? 'Making'
  AND live = '✔ In force'
  AND family = 'CONSTRUCTION' 
  AND geo_extent IN ('England', 'Great Britain');
```

**Performance Impact**: 60-80% reduction in query execution time and database load.

### Ash Framework Integration

#### Enhanced Resource Architecture
- **Organizations Domain:** Extended with progressive profiling capabilities
- **Screening Domain:** New domain for query management and caching
- **Analytics Domain:** Real-time metrics and performance tracking

#### Key Ash Patterns to Implement
- **Code interfaces** with comprehensive filtering options
- **Ash calculations** for organization profile completeness scoring
- **Ash aggregates** for real-time applicable law counts
- **Resource preparations** for dynamic query optimization
- **Custom changes** for profile validation and enhancement

### Phoenix LiveView Strategy

#### Real-Time Update Architecture
- **Event-driven updates** triggered by form input changes
- **Optimistic UI updates** for immediate user feedback
- **Error boundary handling** for graceful failure recovery
- **Performance monitoring** for update latency tracking

#### User Experience Enhancements
- **Progressive disclosure** of form fields based on relevance
- **Live validation** with helpful error messages and suggestions
- **Visual feedback** for data quality and completeness
- **Responsive design** optimized for various screen sizes

---

## 📊 Success Metrics & Validation

### Performance Targets
- **Real-time update latency:** <500ms for law count updates (significantly improved with function filtering)
- **Complex query response time:** <2s for comprehensive organization screening (massive gains from 'Making' subset)
- **Concurrent user capacity:** 100+ simultaneous users
- **Database query optimization:** 70-90% improvement in average query time from Phase 1 through function filtering
- **Function filter efficiency:** Query only 'Making' subset (~20-40% of total records) for duty-creating laws
- **Cache hit rate:** >80% for common organization patterns

### User Experience Metrics
- **Form completion rate:** >85% of started profiles completed
- **User engagement time:** Average session length >5 minutes
- **Error rate:** <2% for form submissions and updates
- **Mobile responsiveness:** Full functionality on mobile devices
- **Accessibility compliance:** WCAG 2.1 AA standards

### Technical Quality Metrics
- **Test coverage:** >90% for core progressive screening logic
- **Code quality:** Consistent Ash framework patterns and conventions
- **Documentation coverage:** Complete API documentation for Phase 3 integration
- **Performance monitoring:** Comprehensive dashboards and alerting

---

## 🔄 Dependencies & Integration Points

### Phase 1 Dependencies
- **Organization schema foundation** - Core organization and user management
- **Basic applicability matching** - Industry sector to family mapping
- **Database setup** - UK LRT schema and initial indexing
- **Phoenix LiveView foundation** - Basic form handling and user authentication

### Phase 3 Preparation
- **API foundations** for AI service integration
- **Data quality validation** framework for AI input
- **Performance baselines** for AI service response time budgets
- **Organization profiling completeness** metrics for AI question generation

### External Dependencies
- **Database optimization** - PostgreSQL performance tuning
- **Cachex dependency** - Add to mix.exs for Elixir-native caching
- **Monitoring tools** - Telemetry and performance dashboards
- **Load testing infrastructure** - Concurrent user testing capabilities

---

## ⚠️ Risk Mitigation & Contingencies

### Technical Risks
- **Database performance degradation** - Implement query timeout limits and fallback strategies
- **Cache consistency issues** - Establish monitoring and automatic cache invalidation
- **LiveView connection limits** - Plan for horizontal scaling and connection pooling
- **JSONB query complexity** - Create simplified fallback queries for performance edge cases

### Implementation Risks
- **Scope creep from Phase 3** - Maintain clear boundaries and defer AI components
- **Performance optimization complexity** - Start with simple solutions and iterate
- **User experience complexity** - Focus on core progressive screening workflow
- **Database migration challenges** - Plan for zero-downtime deployments

### Mitigation Strategies
- **Gradual rollout** - Feature flags for progressive enhancement
- **Performance monitoring** - Real-time alerting and automatic scaling
- **Fallback mechanisms** - Graceful degradation to Phase 1 functionality
- **Comprehensive testing** - Load testing and user acceptance validation

---

## 📅 Milestone Schedule

### Week 1-2: Foundation (Weeks 1-2)
- ✅ Database optimization and JSONB indexing
- ✅ Extended organization schema implementation
- ✅ Performance baseline establishment
- ✅ Caching infrastructure setup

### Week 3-4: Core Engine (Weeks 3-4)
- ✅ Progressive query engine development
- ✅ Enhanced matching logic implementation
- ✅ Real-time update architecture
- ✅ Performance optimization and testing

### Week 5-6: User Experience (Weeks 5-6)
- ✅ Enhanced LiveView implementation
- ✅ Progressive form experience
- ✅ Real-time visualization and feedback
- ✅ Mobile responsiveness and accessibility

### Week 7-8: Production Ready (Weeks 7-8)
- ✅ Comprehensive testing and validation
- ✅ Performance tuning and optimization
- ✅ Monitoring and alerting setup
- ✅ Documentation and Phase 3 preparation

---

## 🚀 Phase 2 Success Definition

**Primary Goal Achieved:** Users receive real-time, progressive feedback on applicable law counts as they complete their organization profile, with professional-grade performance optimized through function-based filtering.

**Key Success Indicators:**
- Real-time updates functioning with <500ms latency using 'Making' function optimization
- Complex JSONB queries performing within 2s response time targets with 60-80% performance improvement
- 100+ concurrent users supported without performance degradation through function-first query strategy
- Enhanced organization profiling capturing all Phase 2 schema requirements
- Function-aware caching and indexing delivering massive performance gains
- Foundation established for Phase 3 AI integration with optimized query patterns

**Phase 3 Readiness:** Enhanced organization profiling data and performance-optimized query architecture ready for AI-powered question generation and Docker Offload integration.