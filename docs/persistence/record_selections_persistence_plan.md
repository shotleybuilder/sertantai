# Long-Term Persistence Plan for Record Selections

## Overview

This document outlines the implementation plan for persistent record selections in the Sertantai application. The goal is to replace the current in-memory ETS storage with a hybrid ETS + database approach that provides both performance and persistence across sessions and server restarts.

## Current State Analysis

### Authentication & User Model
- **Framework**: AshAuthentication with Ash Framework 3.0+
- **User Model**: UUID primary keys, case-insensitive email authentication
- **Security**: bcrypt password hashing, JWT token-based sessions
- **Tenancy**: Single-tenant per user (no organization concept)
- **Current Selection Storage**: In-memory ETS only (lost on restart)

### Security Strengths
- Industry-standard authentication patterns
- User data isolation via foreign key constraints
- Encrypted credential storage for sync configurations
- CSRF protection and session management

### Identified Gaps
- No persistent storage for user selections
- No audit logging for user actions
- No role-based access control
- No multi-tenancy support

## Phase 1: Database Schema Design

### 1.1 Core Tables

#### user_record_selections
Primary table for storing individual record selections per user.

```sql
CREATE TABLE user_record_selections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  record_id UUID NOT NULL REFERENCES uk_lrt_records(id) ON DELETE CASCADE,
  selection_group TEXT DEFAULT 'default',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Ensure one selection per user per record per group
  CONSTRAINT unique_user_record_group UNIQUE(user_id, record_id, selection_group)
);
```

**Security Features:**
- Cascading deletes maintain referential integrity
- Unique constraint prevents duplicate selections
- JSONB metadata for extensible data storage
- User isolation via foreign key constraints

#### user_selection_groups
Optional table for organizing selections into named groups.

```sql
CREATE TABLE user_selection_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  is_default BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_user_group_name UNIQUE(user_id, name)
);
```

#### selection_audit_log
Comprehensive audit trail for all selection changes.

```sql
CREATE TABLE selection_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  record_id UUID NOT NULL REFERENCES uk_lrt_records(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('select', 'deselect', 'bulk_select', 'bulk_deselect', 'clear_all')),
  selection_group TEXT DEFAULT 'default',
  session_id TEXT,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

**Security Features:**
- Complete audit trail for compliance
- IP address and session tracking
- User agent logging for security analysis
- Immutable log entries (no UPDATE operations)

### 1.2 Performance-Optimized Indexes

```sql
-- Core performance indexes
CREATE INDEX idx_user_selections_user_id ON user_record_selections(user_id);
CREATE INDEX idx_user_selections_record_id ON user_record_selections(record_id);
CREATE INDEX idx_user_selections_group ON user_record_selections(user_id, selection_group);
CREATE INDEX idx_user_selections_created_at ON user_record_selections(created_at);

-- Security audit indexes
CREATE INDEX idx_audit_user_id_created_at ON selection_audit_log(user_id, created_at);
CREATE INDEX idx_audit_action_created_at ON selection_audit_log(action, created_at);
CREATE INDEX idx_audit_session_id ON selection_audit_log(session_id);

-- Selection groups
CREATE INDEX idx_selection_groups_user_id ON user_selection_groups(user_id);
CREATE UNIQUE INDEX idx_default_group_per_user ON user_selection_groups(user_id) WHERE is_default = TRUE;
```

## Phase 2: Hybrid Storage Strategy

### 2.1 Architecture Overview

**Two-Tier Storage:**
- **ETS Layer**: Fast in-memory access for active sessions
- **Database Layer**: Persistent storage with full audit trail
- **Background Sync**: Periodic ETS → Database synchronization
- **Cache Invalidation**: Smart cache management on user logout

### 2.2 Enhanced UserSelections Module

```elixir
defmodule Sertantai.UserSelections do
  @moduledoc """
  Manages user record selections with hybrid ETS + Database persistence.
  Provides fast access via ETS with persistent storage and audit logging.
  """
  
  use GenServer
  
  # ETS for fast access
  # Database for persistence
  # Background sync jobs
  # Audit logging integration
end
```

### 2.3 Data Flow

1. **User selects record** → Update ETS immediately → Queue database sync
2. **User loads page** → Check ETS → Fallback to database → Populate ETS
3. **Background sync** → Periodic ETS → Database sync → Audit log entries
4. **User logout** → Force sync ETS → Database → Clear ETS for user

## Phase 3: Security & Compliance

### 3.1 Row-Level Security
- All database queries filtered by authenticated user_id
- Foreign key constraints enforce data isolation
- No cross-user data access possible

### 3.2 Audit Logging
- Complete selection change history
- IP address and session tracking for security analysis
- Immutable audit trail for compliance requirements
- Configurable retention policies

### 3.3 Rate Limiting
- Prevent abuse of bulk selection operations
- Configurable limits per user per time window
- Integration with existing rate limiting infrastructure

## Phase 4: Future Multi-Tenancy Support

### 4.1 Organization Schema Extensions

```sql
-- Optional: Organization/tenant support (future enhancement)
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE user_organization_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member',
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_user_org UNIQUE(user_id, organization_id)
);
```

### 4.2 Shared Selections
- Team-based record selections
- Role-based access to shared selection groups
- Organization-wide compliance and audit requirements

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
- [ ] Create database migrations for core tables
- [ ] Implement basic database persistence in UserSelections
- [ ] Add audit logging infrastructure
- [ ] Comprehensive test suite

### Phase 2: Integration (Week 2)
- [ ] Update RecordSelectionLive to use hybrid storage
- [ ] Implement background sync jobs
- [ ] Add performance monitoring
- [ ] Load testing with concurrent users

### Phase 3: Security & Polish (Week 3)
- [ ] Implement rate limiting
- [ ] Add security monitoring and alerting
- [ ] Data retention automation
- [ ] Documentation and deployment guides

### Phase 4: Advanced Features (Future)
- [ ] Selection groups UI
- [ ] Multi-tenancy support
- [ ] Advanced audit reporting
- [ ] Real-time selection sync via Phoenix Channels

## Database Safety

### Critical Constraints
- **NEVER DELETE** records from uk_lrt_records table
- **CASCADE DELETES** only affect user-owned selection data
- **Foreign key constraints** prevent orphaned selections
- **Backup strategy** for selection data before major changes

### Testing Strategy
- Comprehensive unit tests for all database operations
- Integration tests for hybrid ETS + Database flow
- Load testing for concurrent user scenarios
- Security testing for access control and audit logging

## Success Metrics

### Performance
- ETS read/write operations < 1ms
- Database sync operations < 100ms
- Page load times with selections < 2s
- Support for 100+ concurrent users

### Security
- Complete audit trail for all operations
- Zero cross-user data access incidents
- Proper data isolation and access controls
- Compliance with data retention policies

### Reliability
- 99.9% uptime for selection persistence
- Zero data loss during server restarts
- Graceful fallback when ETS/Database unavailable
- Automatic recovery from sync failures

---

*This plan provides enterprise-grade persistence with security-first design while maintaining backward compatibility and preparing for future multi-tenancy needs.*