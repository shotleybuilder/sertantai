# Multi-Location Organization Migration Guide

## Overview

This guide provides step-by-step instructions for migrating existing single-location organizations to the new multi-location model, handling data consistency during the transition, and ensuring backward compatibility.

## Migration Strategy

### Automatic Migration (Recommended)

The system automatically migrates existing organizations during the database migration process. This ensures:

- **Zero Downtime**: Migration happens during regular deployment
- **Data Integrity**: All existing organizations become valid single-location organizations
- **Backward Compatibility**: No changes to existing user workflows

### Migration Process

#### Step 1: Pre-Migration Validation

Before running migrations, validate your data:

```bash
# Check existing organizations
mix run -e "
IO.puts('Total organizations: #{Ash.count!(Sertantai.Organizations.Organization, domain: Sertantai.Organizations)}')
"

# Verify core_profile data integrity
mix run scripts/validate_organization_profiles.exs
```

#### Step 2: Database Backup

**Critical**: Always backup your database before migration:

```bash
# For production (Supabase)
pg_dump $DATABASE_URL > backup_before_multi_location_$(date +%Y%m%d_%H%M%S).sql

# For local development
docker exec sertantai-postgres pg_dump -U postgres sertantai_dev > backup_dev_$(date +%Y%m%d_%H%M%S).sql
```

#### Step 3: Run Migration

```bash
# Generate any pending Ash resource migrations
mix ash.codegen --check

# Apply database migrations
mix ecto.migrate

# Verify migration success
mix run -e "
IO.puts('Organizations: #{Ash.count!(Sertantai.Organizations.Organization, domain: Sertantai.Organizations)}')
IO.puts('Locations: #{Ash.count!(Sertantai.Organizations.OrganizationLocation, domain: Sertantai.Organizations)}')
"
```

#### Step 4: Data Validation

Verify the migration results:

```bash
# Run validation script
mix run scripts/validate_multi_location_migration.exs
```

## Data Migration Details

### Organization to Location Mapping

Each existing organization is automatically converted to have a primary headquarters location:

**Before Migration** (Organization):
```elixir
%{
  id: "org-123",
  organization_name: "ACME Construction Ltd",
  core_profile: %{
    "organization_name" => "ACME Construction Ltd",
    "organization_type" => "limited_company",
    "headquarters_region" => "england",
    "industry_sector" => "construction",
    "total_employees" => 75
  }
}
```

**After Migration** (Organization + Location):
```elixir
# Organization (unchanged)
%{
  id: "org-123",
  organization_name: "ACME Construction Ltd",
  core_profile: %{...}  # Remains the same
}

# New Primary Location
%{
  id: "loc-456",
  organization_id: "org-123",
  location_name: "Headquarters",
  location_type: :headquarters,
  address: %{"region" => "england"},
  geographic_region: "england",
  is_primary_location: true,
  operational_status: :active,
  industry_activities: ["construction"],
  operational_profile: %{
    "total_employees" => 75,
    "industry_sector" => "construction",
    "organization_type" => "limited_company"
  }
}
```

### Field Mapping

| Organization Field | Location Field | Notes |
|-------------------|----------------|-------|
| `core_profile["headquarters_region"]` | `geographic_region` | Direct mapping |
| `core_profile["industry_sector"]` | `industry_activities[0]` | Converted to array |
| `core_profile["total_employees"]` | `employee_count` | Direct mapping |
| `organization_name` | `location_name` = "Headquarters" | Default name |
| N/A | `location_type` = `:headquarters` | Default type |
| N/A | `is_primary_location` = `true` | All become primary |
| N/A | `operational_status` = `:active` | Default status |

## Post-Migration Verification

### Data Consistency Checks

Run these queries to verify migration success:

```elixir
# 1. Verify every organization has exactly one location
organizations_without_locations = 
  Sertantai.Organizations.Organization
  |> Ash.Query.filter(count(locations) == 0)
  |> Ash.read!(domain: Sertantai.Organizations)

# Should be empty []
IO.inspect(organizations_without_locations, label: "Organizations without locations")

# 2. Verify every organization has exactly one primary location
organizations_without_primary = 
  Sertantai.Organizations.Organization
  |> Ash.Query.filter(count(locations, filter: locations.is_primary_location == true) != 1)
  |> Ash.read!(domain: Sertantai.Organizations)

# Should be empty []
IO.inspect(organizations_without_primary, label: "Organizations without primary location")

# 3. Verify SingleLocationAdapter works correctly
{:ok, organizations} = Ash.read(
  Sertantai.Organizations.Organization,
  load: [:locations],
  domain: Sertantai.Organizations
)

for org <- organizations do
  mode = Sertantai.Organizations.SingleLocationAdapter.interface_mode(org)
  IO.puts("Organization #{org.organization_name}: #{mode}")
  # All should show :single_location
end
```

### Application Testing

Test key workflows to ensure backward compatibility:

```bash
# 1. Run existing tests
mix test

# 2. Test organization profile access
mix run -e "
{:ok, org} = Ash.get(Sertantai.Organizations.Organization, 'your-org-id', 
  load: [:locations], domain: Sertantai.Organizations)

legacy_profile = Sertantai.Organizations.SingleLocationAdapter.get_legacy_profile(org)
IO.inspect(legacy_profile, label: 'Legacy profile')
"

# 3. Test screening workflow
# Navigate to /applicability/smart in your browser
# Should automatically route to location-specific screening
```

## Rollback Procedures

### Emergency Rollback

If issues are discovered post-migration:

```bash
# 1. Stop application
# 2. Restore database from backup
psql $DATABASE_URL < backup_before_multi_location_YYYYMMDD_HHMMSS.sql

# 3. Rollback migrations
mix ecto.rollback --step 3

# 4. Restart application
```

### Selective Data Restoration

If only specific organizations need restoration:

```sql
-- Restore specific organization data
BEGIN;

-- Backup current state
CREATE TEMP TABLE org_backup AS 
SELECT * FROM organizations WHERE id = 'problematic-org-id';

-- Restore from backup
UPDATE organizations 
SET core_profile = (SELECT core_profile FROM backup_table WHERE id = 'problematic-org-id')
WHERE id = 'problematic-org-id';

-- Remove problematic locations
DELETE FROM organization_locations WHERE organization_id = 'problematic-org-id';

-- Re-run migration for this organization only
-- (Custom script would be needed)

COMMIT;
```

## Adding Additional Locations

### For Migrated Organizations

After migration, organizations can add additional locations:

```elixir
# Example: Add second location to existing organization
{:ok, organization} = Ash.get(
  Sertantai.Organizations.Organization, 
  "org-123",
  domain: Sertantai.Organizations
)

# Add branch office
{:ok, branch_location} = Ash.create(
  Sertantai.Organizations.OrganizationLocation,
  %{
    organization_id: organization.id,
    location_name: "Manchester Branch",
    location_type: :branch_office,
    address: %{
      "street" => "456 Industrial Estate",
      "city" => "Manchester",
      "postcode" => "M1 2AB"
    },
    geographic_region: "england",
    employee_count: 25,
    industry_activities: ["construction", "project_management"],
    operational_status: :active,
    is_primary_location: false  # Not primary
  },
  domain: Sertantai.Organizations
)

# Organization now becomes multi-location
{:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
mode = Sertantai.Organizations.SingleLocationAdapter.interface_mode(org_with_locations)
# mode will now be :multi_location
```

### Interface Behavior Change

When an organization transitions from single to multi-location:

**Before (Single Location)**:
- Smart routing: `/applicability/smart` → `/applicability/location/{location-id}`
- Interface mode: `:single_location`
- Navigation: Simplified, direct to screening

**After (Multi Location)**:
- Smart routing: `/applicability/smart` → `/applicability/organization/aggregate`
- Interface mode: `:multi_location`  
- Navigation: Location management → Individual location screening OR organization-wide aggregate

## Updating Existing Screening Results

### Location-Aware Screening Migration

If you have existing screening results that need to be made location-aware:

```elixir
# Create script: scripts/migrate_screening_results.exs

# Get all organizations with their primary locations
{:ok, organizations} = Ash.read(
  Sertantai.Organizations.Organization,
  load: [:locations, :primary_location],
  domain: Sertantai.Organizations
)

for org <- organizations do
  case org.primary_location do
    %{id: location_id} ->
      # Update any existing screening sessions to reference the primary location
      # This would depend on your existing screening data structure
      
      # Example if you have screening sessions to migrate:
      # existing_sessions = get_org_screening_sessions(org.id)
      # 
      # for session <- existing_sessions do
      #   create_location_screening_from_session(session, location_id)
      # end
      
      IO.puts("Migrated screening data for #{org.organization_name}")
    
    nil ->
      IO.puts("Warning: #{org.organization_name} has no primary location")
  end
end
```

## Data Consistency Maintenance

### Ongoing Validation

Create a regular validation task:

```elixir
# Create: scripts/validate_location_consistency.exs

defmodule LocationConsistencyValidator do
  def run do
    validate_primary_locations()
    validate_organization_location_relationships()
    validate_interface_mode_consistency()
  end

  def validate_primary_locations do
    # Each organization should have exactly one primary location
    issues = 
      Sertantai.Organizations.Organization
      |> Ash.Query.load([:locations])
      |> Ash.read!(domain: Sertantai.Organizations)
      |> Enum.filter(fn org ->
        primary_count = 
          org.locations
          |> Enum.count(&(&1.is_primary_location))
        
        primary_count != 1
      end)
    
    if issues != [] do
      IO.puts("❌ Organizations with primary location issues:")
      for org <- issues do
        primary_count = Enum.count(org.locations, &(&1.is_primary_location))
        IO.puts("  - #{org.organization_name}: #{primary_count} primary locations")
      end
    else
      IO.puts("✅ All organizations have exactly one primary location")
    end
  end

  def validate_organization_location_relationships do
    # Verify all locations belong to valid organizations
    orphaned_locations = 
      Sertantai.Organizations.OrganizationLocation
      |> Ash.Query.filter(is_nil(organization_id))
      |> Ash.read!(domain: Sertantai.Organizations)
    
    if orphaned_locations != [] do
      IO.puts("❌ Found #{length(orphaned_locations)} orphaned locations")
    else
      IO.puts("✅ All locations have valid organization relationships")
    end
  end

  def validate_interface_mode_consistency do
    # Verify SingleLocationAdapter logic works for all organizations
    {:ok, organizations} = Ash.read(
      Sertantai.Organizations.Organization,
      load: [:locations],
      domain: Sertantai.Organizations
    )
    
    inconsistencies = 
      organizations
      |> Enum.filter(fn org ->
        location_count = length(org.locations)
        interface_mode = Sertantai.Organizations.SingleLocationAdapter.interface_mode(org)
        
        case {location_count, interface_mode} do
          {0, :no_locations} -> false
          {1, :single_location} -> false
          {n, :multi_location} when n > 1 -> false
          _ -> true  # Inconsistent
        end
      end)
    
    if inconsistencies != [] do
      IO.puts("❌ Found interface mode inconsistencies:")
      for org <- inconsistencies do
        count = length(org.locations)
        mode = Sertantai.Organizations.SingleLocationAdapter.interface_mode(org)
        IO.puts("  - #{org.organization_name}: #{count} locations, mode: #{mode}")
      end
    else
      IO.puts("✅ All organizations have consistent interface modes")
    end
  end
end

LocationConsistencyValidator.run()
```

Run this validation monthly or after any data imports:

```bash
mix run scripts/validate_location_consistency.exs
```

## Performance Considerations

### Database Indexing

Ensure proper indexes are in place after migration:

```sql
-- Verify indexes exist
\d organization_locations

-- Key indexes for performance:
-- - organization_locations_organization_id_index
-- - organization_locations_geographic_region_index  
-- - organization_locations_location_type_index
-- - organization_locations_operational_status_index
-- - organization_locations_organization_id_location_name_index (unique)
-- - organization_locations_one_primary_per_org (unique, partial)
```

### Query Performance

Monitor query performance for common operations:

```elixir
# Before migration - simple organization query
{:ok, org} = Ash.get(Organization, "org-123", domain: Sertantai.Organizations)

# After migration - organization with locations (more complex)
{:ok, org} = Ash.get(
  Organization, 
  "org-123", 
  load: [:locations, :primary_location],
  domain: Sertantai.Organizations
)
```

If performance issues arise, consider:
- Eager loading only necessary relationships
- Using calculations instead of loading full location data
- Implementing caching for frequently accessed organization-location combinations

## Troubleshooting

### Common Issues

#### 1. Organizations Without Primary Location

**Symptom**: `SingleLocationAdapter.get_primary_location/1` returns `{:error, :no_primary_location}`

**Solution**:
```elixir
# Fix specific organization
{:ok, org} = Ash.get(Organization, "problematic-org-id", 
  load: [:locations], domain: Sertantai.Organizations)

case org.locations do
  [] -> 
    # Create missing headquarters location
    create_default_headquarters_location(org)
  
  [location] ->
    # Mark existing location as primary
    Ash.update!(location, %{is_primary_location: true}, 
      domain: Sertantai.Organizations)
  
  multiple_locations ->
    # Identify which should be primary (usually headquarters type)
    primary = Enum.find(multiple_locations, &(&1.location_type == :headquarters)) ||
              List.first(multiple_locations)
    
    # Unmark all others, mark one as primary
    for loc <- multiple_locations do
      Ash.update!(loc, %{is_primary_location: loc.id == primary.id},
        domain: Sertantai.Organizations)
    end
end
```

#### 2. Interface Mode Detection Issues

**Symptom**: Wrong interface mode returned by `SingleLocationAdapter.interface_mode/1`

**Diagnosis**:
```elixir
# Debug organization state
{:ok, org} = Ash.get(Organization, "org-id", 
  load: [:locations], domain: Sertantai.Organizations)

IO.puts("Locations loaded: #{is_list(org.locations)}")
IO.puts("Location count: #{length(org.locations || [])}")
IO.puts("Interface mode: #{SingleLocationAdapter.interface_mode(org)}")

# Check each location
for location <- (org.locations || []) do
  IO.puts("Location: #{location.location_name}, Primary: #{location.is_primary_location}")
end
```

#### 3. Screening Route Issues

**Symptom**: Smart routing leads to wrong page

**Solution**:
```elixir
# Test routing logic
{:ok, org} = Ash.get(Organization, "org-id", 
  load: [:locations], domain: Sertantai.Organizations)

{mode, route} = SingleLocationAdapter.get_screening_route(org)
IO.puts("Mode: #{mode}, Route: #{route}")

# Verify route is accessible
# Navigate to the route in browser to test
```

## Migration Validation Checklist

Use this checklist to verify successful migration:

### Pre-Migration
- [ ] Database backup completed
- [ ] All organizations have valid `core_profile` data
- [ ] Development environment tested successfully
- [ ] Rollback procedure tested

### During Migration
- [ ] `mix ash.codegen --check` runs without errors
- [ ] `mix ecto.migrate` completes successfully
- [ ] No error messages in migration output
- [ ] Organization and location counts match expectations

### Post-Migration
- [ ] All organizations have exactly one location
- [ ] All locations have `is_primary_location: true`
- [ ] `SingleLocationAdapter.interface_mode/1` returns `:single_location` for all orgs
- [ ] Smart routing works: `/applicability/smart` redirects correctly
- [ ] Existing user workflows unchanged
- [ ] Performance is acceptable
- [ ] All tests pass: `mix test`

### User Acceptance
- [ ] Users can access organization profiles as before
- [ ] Screening workflows work identically to before
- [ ] No UI changes for single-location users
- [ ] Location management accessible but optional

## Next Steps

After successful migration:

1. **Monitor Performance**: Watch for any performance regressions in the first week
2. **User Training**: Prepare documentation for users who want to add additional locations
3. **Feature Rollout**: Consider gradual rollout of multi-location features
4. **Data Quality**: Regular validation of location data consistency

The migration preserves all existing functionality while enabling powerful multi-location capabilities for organizations that need them.