# Location Management API Guide

## Overview

This guide documents the API endpoints and data structures for managing organization locations in the Sertantai multi-location system.

## Core Resources

### OrganizationLocation Resource

The `OrganizationLocation` resource represents a specific operational site for an organization.

#### Schema Definition

```elixir
defmodule Sertantai.Organizations.OrganizationLocation do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Sertantai.Organizations

  attributes do
    uuid_primary_key :id
    
    # Location identification
    attribute :location_name, :string, allow_nil?: false
    attribute :location_type, :atom do
      constraints one_of: [:headquarters, :branch_office, :warehouse, 
                           :manufacturing_site, :retail_outlet, :project_site, 
                           :temporary_location, :home_office, :other]
      default :branch_office
    end
    
    # Geographic details
    attribute :address, :map, allow_nil?: false
    attribute :geographic_region, :string, allow_nil?: false
    attribute :postcode, :string
    attribute :local_authority, :string
    
    # Operational characteristics
    attribute :operational_profile, :map, default: %{}
    attribute :employee_count, :integer
    attribute :annual_revenue, :decimal
    attribute :operational_status, :atom do
      constraints one_of: [:active, :inactive, :seasonal, :under_construction, :closing]
      default :active
    end
    
    # Regulatory context
    attribute :industry_activities, {:array, :string}, default: []
    attribute :environmental_factors, :map, default: %{}
    attribute :health_safety_profile, :map, default: %{}
    attribute :data_processing_activities, {:array, :string}, default: []
    
    # Metadata
    attribute :is_primary_location, :boolean, default: false
    attribute :established_date, :date
    attribute :compliance_notes, :string
    
    timestamps()
  end
end
```

#### Required Fields

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `organization_id` | UUID | Parent organization | Must exist in organizations table |
| `location_name` | String | Human-readable location name | Required, unique per organization |
| `address` | Map | Full address structure | Required, see Address Schema |
| `geographic_region` | String | Geographic region code | Required, enum values |

#### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `location_type` | Atom | `:branch_office` | Type of operational site |
| `postcode` | String | `nil` | Postal/ZIP code |
| `local_authority` | String | `nil` | Local government area |
| `operational_profile` | Map | `%{}` | Custom operational data |
| `employee_count` | Integer | `nil` | Number of employees at location |
| `annual_revenue` | Decimal | `nil` | Location-specific revenue |
| `operational_status` | Atom | `:active` | Current operational status |
| `industry_activities` | Array[String] | `[]` | Industry activities performed |
| `environmental_factors` | Map | `%{}` | Environmental characteristics |
| `health_safety_profile` | Map | `%{}` | Health & safety data |
| `data_processing_activities` | Array[String] | `[]` | GDPR-relevant data processing |
| `is_primary_location` | Boolean | `false` | Primary location flag |
| `established_date` | Date | `nil` | When location was established |
| `compliance_notes` | String | `nil` | Free-text compliance notes |

## Data Structures

### Address Schema

The `address` field uses a flexible map structure:

```elixir
# Minimal address
%{
  "region" => "england"
}

# Full address
%{
  "street" => "123 Industrial Way",
  "city" => "Birmingham", 
  "postcode" => "B1 1AA",
  "county" => "West Midlands",
  "country" => "United Kingdom",
  "region" => "england"
}

# International address
%{
  "street" => "45 Rue de Commerce",
  "city" => "Paris",
  "postcode" => "75001", 
  "country" => "France",
  "region" => "france"
}
```

### Geographic Regions

Valid `geographic_region` values:

```elixir
[
  "england",
  "scotland", 
  "wales",
  "northern_ireland",
  "ireland",
  "france",
  "germany",
  "spain",
  "italy",
  "netherlands",
  "belgium",
  "other_eu",
  "usa",
  "canada",
  "australia",
  "other_international"
]
```

### Location Types

Valid `location_type` values:

```elixir
[
  :headquarters,        # Main corporate office
  :branch_office,       # Regional/local office
  :warehouse,          # Storage and distribution
  :manufacturing_site, # Production facility  
  :retail_outlet,      # Customer-facing store
  :project_site,       # Temporary project location
  :temporary_location, # Short-term operational site
  :home_office,        # Remote/home-based operation
  :other              # Other operational type
]
```

### Operational Status

Valid `operational_status` values:

```elixir
[
  :active,             # Currently operational
  :inactive,           # Not currently operational
  :seasonal,           # Operates seasonally
  :under_construction, # Being built/renovated
  :closing            # In process of closure
]
```

## API Actions

### Create Location

Create a new organization location:

```elixir
# Basic creation
{:ok, location} = Ash.create(
  Sertantai.Organizations.OrganizationLocation,
  %{
    organization_id: "org-123",
    location_name: "Manchester Branch",
    location_type: :branch_office,
    address: %{
      "street" => "456 Business Park",
      "city" => "Manchester", 
      "postcode" => "M1 2AB"
    },
    geographic_region: "england",
    employee_count: 25
  },
  domain: Sertantai.Organizations
)
```

#### Validation Rules

- `location_name` must be unique within the organization
- Only one location per organization can have `is_primary_location: true`
- `organization_id` must reference an existing organization
- `geographic_region` must be a valid region code
- `location_type` must be a valid enum value

### Read Locations

#### Get Single Location

```elixir
{:ok, location} = Ash.get(
  Sertantai.Organizations.OrganizationLocation,
  "location-id",
  domain: Sertantai.Organizations
)
```

#### Get Organization's Locations

```elixir
{:ok, organization} = Ash.get(
  Sertantai.Organizations.Organization,
  "org-id",
  load: [:locations],
  domain: Sertantai.Organizations
)

locations = organization.locations
```

#### Filter Locations

```elixir
# Active locations only
{:ok, active_locations} = Ash.read(
  Sertantai.Organizations.OrganizationLocation,
  filter: [operational_status: :active],
  domain: Sertantai.Organizations
)

# Locations by region
{:ok, england_locations} = Ash.read(
  Sertantai.Organizations.OrganizationLocation,
  filter: [geographic_region: "england"],
  domain: Sertantai.Organizations
)

# Organization's primary location
{:ok, primary_location} = Ash.read_one(
  Sertantai.Organizations.OrganizationLocation,
  filter: [organization_id: "org-id", is_primary_location: true],
  domain: Sertantai.Organizations
)
```

### Update Location

```elixir
{:ok, updated_location} = Ash.update(
  location,
  %{
    employee_count: 30,
    operational_status: :active,
    compliance_notes: "Updated safety procedures implemented"
  },
  domain: Sertantai.Organizations
)
```

### Delete Location

```elixir
:ok = Ash.destroy(location, domain: Sertantai.Organizations)
```

**Note**: Cannot delete the last remaining location if it's marked as primary. Must either add another location first or update the organization's structure.

## Data Examples

### Minimal Location

```elixir
%{
  organization_id: "01234567-89ab-cdef-0123-456789abcdef",
  location_name: "Head Office",
  address: %{"region" => "england"},
  geographic_region: "england"
}
```

### Comprehensive Location

```elixir
%{
  organization_id: "01234567-89ab-cdef-0123-456789abcdef",
  location_name: "Birmingham Manufacturing Plant",
  location_type: :manufacturing_site,
  address: %{
    "street" => "123 Industrial Estate",
    "city" => "Birmingham",
    "postcode" => "B12 3CD",
    "county" => "West Midlands",
    "country" => "United Kingdom"
  },
  geographic_region: "england",
  postcode: "B12 3CD",
  local_authority: "Birmingham City Council",
  operational_profile: %{
    "machinery_types" => ["injection_molding", "assembly_line"],
    "shift_patterns" => ["day", "night"], 
    "production_capacity" => "10000_units_per_month",
    "certifications" => ["ISO9001", "ISO14001"]
  },
  employee_count: 150,
  annual_revenue: Decimal.new("2500000.00"),
  operational_status: :active,
  industry_activities: ["manufacturing", "assembly", "quality_control", "packaging"],
  environmental_factors: %{
    "emissions_level" => "moderate",
    "waste_types" => ["plastic", "metal", "packaging"],
    "energy_consumption" => "high",
    "water_usage" => "moderate"
  },
  health_safety_profile: %{
    "hazard_level" => "medium",
    "ppe_required" => true,
    "safety_training_frequency" => "quarterly",
    "incident_rate" => "low"
  },
  data_processing_activities: ["employee_records", "production_data", "quality_metrics"],
  is_primary_location: false,
  established_date: ~D[2018-03-15],
  compliance_notes: "Regular HSE inspections passed. ISO certifications current."
}
```