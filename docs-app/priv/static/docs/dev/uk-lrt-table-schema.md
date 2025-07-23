---
title: UK LRT Table Schema Reference
description: Complete schema documentation for the uk_lrt table in the development database
categories: [Database, Schema]
tags: [uk_lrt, database-schema, postgresql]
visibility: dev
status: current
created_at: 2025-07-22
updated_at: 2025-07-22
---

# UK LRT Table Schema Reference

## Overview

The `uk_lrt` table contains UK Legislative Resources and Tools data imported from the production database. The development database currently contains **19,089 records** spanning from year 1267 to 2025.

## Table Statistics

| Metric | Value |
|--------|-------|
| Total Records | 19,089 |
| Distinct Families | 53 |
| Distinct Types | 23 |
| Distinct Years | 136 |
| Earliest Year | 1267 |
| Latest Year | 2025 |
| Live Records (Y) | 0 |
| Not Live Records (N) | 0 |

## Column Schema

The table contains **123 columns** with varying data population levels. Below is the complete schema:

### Core Identification Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| id | uuid | NO | - | ✅ All records |
| family | varchar(255) | YES | - | ✅ 13,093 records |
| family_ii | varchar(255) | YES | - | ❌ Not populated |
| name | varchar(255) | YES | - | ✅ All records |
| year | integer | YES | - | ✅ All records |
| number | varchar(255) | YES | - | ✅ 19,088 records |
| number_int | integer | YES | - | ❌ Not populated |

### Classification & Type Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| type_desc | varchar(255) | YES | - | ✅ 18,561 records |
| type_code | text | YES | - | ❌ Not populated |
| type_class | text | YES | - | ❌ Not populated |
| 2ndary_class | varchar(255) | YES | - | ❌ Not populated |
| live | varchar(255) | YES | - | ✅ 16,863 records |
| live_description | text | YES | - | ❌ Not populated |

### Title & Description Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| title_en | text | YES | - | ✅ 14,704 records (77.03%) |
| title_en_year | text | YES | - | ❌ Not populated |
| title_en_year_number | text | YES | - | ❌ Not populated |
| md_description | text | YES | - | ✅ 16,317 records (85.48%) |
| acronym | text | YES | - | ❌ Not populated |
| old_style_number | text | YES | - | ❌ Not populated |

### Date Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| created_at | timestamp | YES | - | ✅ All records (100%) |
| md_date | date | YES | - | ✅ 13,610 records (71.30%) |
| md_date_year | integer | YES | - | ✅ 13,610 records (71.30%) |
| md_date_month | integer | YES | - | ✅ 13,610 records (71.30%) |
| md_made_date | date | YES | - | ❌ Not populated |
| md_enactment_date | date | YES | - | ❌ Not populated |
| md_coming_into_force_date | date | YES | - | ❌ Not populated |
| md_dct_valid_date | date | YES | - | ❌ Not populated |
| md_restrict_start_date | date | YES | - | ❌ Not populated |
| latest_change_date | date | YES | - | ❌ Not populated |
| latest_change_date_year | smallint | YES | - | ❌ Not populated |
| latest_change_date_month | smallint | YES | - | ❌ Not populated |
| latest_amend_date | date | YES | - | ❌ Not populated |
| latest_amend_date_year | integer | YES | - | ❌ Not populated |
| latest_amend_date_month | integer | YES | - | ❌ Not populated |
| latest_rescind_date | date | YES | - | ❌ Not populated |
| latest_rescind_date_year | integer | YES | - | ❌ Not populated |
| latest_rescind_date_month | integer | YES | - | ❌ Not populated |
| revoked_by__latest_date__ | date | YES | - | ❌ Not populated |
| year__from_revoked_by__latest_date__ | numeric | YES | - | ❌ Not populated |
| month__from_revoked_by__latest_date__ | numeric | YES | - | ❌ Not populated |

### Role & Responsibility Columns (JSONB)

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| duty_holder | jsonb | YES | - | ❌ Not populated |
| power_holder | jsonb | YES | - | ❌ Not populated |
| rights_holder | jsonb | YES | - | ❌ Not populated |
| responsibility_holder | jsonb | YES | - | ❌ Not populated |
| role_gvt | jsonb | YES | - | ❌ Not populated |
| function | jsonb | YES | - | ❌ Not populated |
| purpose | jsonb | YES | - | ❌ Not populated |
| is_affecting | jsonb | YES | - | ❌ Not populated |

### Array Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| role | ARRAY | YES | - | ❌ Not populated |
| tags | ARRAY | YES | - | ❌ Not populated |
| amending | ARRAY | YES | - | ❌ Not populated |
| amended_by | ARRAY | YES | - | ❌ Not populated |
| linked_amending | ARRAY | YES | - | ❌ Not populated |
| linked_amended_by | ARRAY | YES | - | ❌ Not populated |
| rescinding | ARRAY | YES | - | ❌ Not populated |
| rescinded_by | ARRAY | YES | - | ❌ Not populated |
| linked_rescinding | ARRAY | YES | - | ❌ Not populated |
| linked_rescinded_by | ARRAY | YES | - | ❌ Not populated |
| enacting | ARRAY | YES | - | ❌ Not populated |
| enacted_by | ARRAY | YES | - | ❌ Not populated |
| linked_enacted_by | ARRAY | YES | - | ❌ Not populated |

### Geographic Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| geo_extent | text | YES | - | ❌ Not populated |
| geo_region | text | YES | - | ❌ Not populated |
| geo_country | jsonb | YES | - | ❌ Not populated |
| md_restrict_extent | text | YES | - | ❌ Not populated |

### Article/Clause Reference Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| article_role | text | YES | - | ❌ Not populated |
| role_article | text | YES | - | ❌ Not populated |
| article_duty_holder | text | YES | - | ❌ Not populated |
| duty_holder_article | text | YES | - | ❌ Not populated |
| article_power_holder | text | YES | - | ❌ Not populated |
| power_holder_article | text | YES | - | ❌ Not populated |
| article_rights_holder | text | YES | - | ❌ Not populated |
| rights_holder_article | text | YES | - | ❌ Not populated |
| article_responsibility_holder | varchar(255) | YES | - | ❌ Not populated |
| responsibility_holder_article | varchar(255) | YES | - | ❌ Not populated |
| article_duty_holder_clause | text | YES | - | ❌ Not populated |
| duty_holder_article_clause | text | YES | - | ❌ Not populated |
| article_power_holder_clause | text | YES | - | ❌ Not populated |
| power_holder_article_clause | text | YES | - | ❌ Not populated |
| article_rights_holder_clause | varchar(255) | YES | - | ❌ Not populated |
| rights_holder_article_clause | varchar(255) | YES | - | ❌ Not populated |
| article_responsibility_holder_clause | varchar(255) | YES | - | ❌ Not populated |
| responsibility_holder_article_clause | varchar(255) | YES | - | ❌ Not populated |
| article_popimar_clause | text | YES | - | ❌ Not populated |
| popimar_article_clause | text | YES | - | ❌ Not populated |

### Metadata & Content Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| md_total_paras | numeric | YES | - | ❌ Not populated |
| md_body_paras | smallint | YES | - | ❌ Not populated |
| md_schedule_paras | smallint | YES | - | ❌ Not populated |
| md_attachment_paras | smallint | YES | - | ❌ Not populated |
| md_images | smallint | YES | - | ❌ Not populated |
| md_change_log | text | YES | - | ❌ Not populated |
| md_modify_en | text | YES | - | ❌ Not populated |
| md_effect_en | text | YES | - | ❌ Not populated |
| md_popimar_paras | text | YES | - | ❌ Not populated |
| popimar_paras | text | YES | - | ❌ Not populated |
| body | text | YES | - | ❌ Not populated |
| schedule | text | YES | - | ❌ Not populated |
| attachment | text | YES | - | ❌ Not populated |

### Status & Flag Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| is_amending | boolean | YES | - | ❌ Not populated |
| is_rescinding | boolean | YES | - | ❌ Not populated |
| is_enacting | boolean | YES | - | ❌ Not populated |
| is_making | numeric | YES | - | ❌ Not populated |
| is_commencing | numeric | YES | - | ❌ Not populated |
| enacted_by_description | text | YES | - | ❌ Not populated |

### Count & Metric Columns (with special characters)

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| △_#_amd_by_law | smallint | YES | - | ❌ Not populated |
| ▽_#_amd_of_law | smallint | YES | - | ❌ Not populated |
| △_#_laws_rsc_law | smallint | YES | - | ❌ Not populated |
| ▽_#_laws_rsc_law | smallint | YES | - | ❌ Not populated |
| △_#_laws_amd_law | smallint | YES | - | ❌ Not populated |
| ▽_#_laws_amd_law | smallint | YES | - | ❌ Not populated |
| △_#_laws_amd_by_law | smallint | YES | - | ❌ Not populated |
| △_#_self_amd_by_law | smallint | YES | - | ❌ Not populated |
| ▽_#_self_amd_of_law | smallint | YES | - | ❌ Not populated |
| △_amd_short_desc | text | YES | - | ❌ Not populated |
| △_amd_long_desc | text | YES | - | ❌ Not populated |
| ▽_amd_short_desc | text | YES | - | ❌ Not populated |
| ▽_amd_long_desc | text | YES | - | ❌ Not populated |
| △_rsc_short_desc | text | YES | - | ❌ Not populated |
| △_rsc_long_desc | text | YES | - | ❌ Not populated |
| ▽_rsc_short_desc | text | YES | - | ❌ Not populated |
| ▽_rsc_long_desc | text | YES | - | ❌ Not populated |

### External Reference Columns

| Column Name | Data Type | Nullable | Default | Data Populated |
|------------|-----------|----------|---------|----------------|
| leg_gov_uk_url | text | YES | - | ❌ Not populated |
| si_code | jsonb | YES | - | ❌ Not populated |
| __e_register | text | YES | - | ❌ Not populated |
| __hs_register | text | YES | - | ❌ Not populated |
| __hr_register | text | YES | - | ❌ Not populated |

## Indexes

The table has **14 indexes** for performance optimization:

1. **uk_lrt_pkey** - Primary key index on `id` (UNIQUE)
2. **uk_lrt_family_index** - B-tree index on `family`
3. **uk_lrt_family_ii_index** - B-tree index on `family_ii`
4. **uk_lrt_year_index** - B-tree index on `year`
5. **idx_uk_lrt_live** - B-tree index on `live`
6. **idx_uk_lrt_family** - B-tree index on `family` (duplicate?)
7. **idx_uk_lrt_geo_extent** - B-tree index on `geo_extent`
8. **idx_uk_lrt_duty_holder_gin** - GIN index on `duty_holder` (JSONB)
9. **idx_uk_lrt_role_gin** - GIN index on `role` (Array)
10. **idx_uk_lrt_tags_gin** - GIN index on `tags` (Array)
11. **idx_uk_lrt_live_family_geo** - Composite B-tree index on `live, family, geo_extent`
12. **idx_uk_lrt_function_making** - Partial GIN index on `function` WHERE `function ? 'Making'`
13. **idx_uk_lrt_purpose_gin** - GIN index on `purpose` (JSONB)
14. **idx_uk_lrt_function_composite** - Composite partial B-tree index on `family, geo_extent, live` WHERE `function ? 'Making'`

## Constraints

- **uk_lrt_pkey** - Primary key constraint on `id` column

## Data Population Summary

### Well-Populated Columns (>50% data)
- `id` - 100% (all records)
- `name` - 100% (all records) 
- `year` - 100% (all records)
- `created_at` - 100% (all records)
- `number` - 99.99% (19,088/19,089)
- `type_desc` - 97.23% (18,561/19,089)
- `live` - 88.35% (16,863/19,089)
- `md_description` - 85.48% (16,317/19,089)
- `title_en` - 77.03% (14,704/19,089)
- `md_date` - 71.30% (13,610/19,089)
- `md_date_year` - 71.30% (13,610/19,089)
- `md_date_month` - 71.30% (13,610/19,089)
- `family` - 68.59% (13,093/19,089)

### Columns Requiring Data Import
The following columns exist in the schema but have limited or no data in the development database:
- **Remaining date columns** (latest_change_date, md_made_date, md_enactment_date, etc.)
- **JSONB columns** (duty_holder, power_holder, geo_country, etc.)
- **Array columns** (role, tags, amending, etc.)
- **Text content columns** (body, schedule, attachment)
- **Article/clause reference columns** (for detailed citation features)
- **External reference columns** (leg_gov_uk_url, si_code, etc.)

## Recommendations for Additional Data Import

Based on the current schema and data population:

1. **Priority 1 - Core Metadata** ✅ **COMPLETED**
   - ✅ `title_en` - **77.03% populated** (14,704/19,089 records)
   - ✅ `md_description` - **85.48% populated** (16,317/19,089 records) 
   - ✅ `created_at` - **100% populated** (all records)
   - ✅ `md_date`, `md_date_year`, `md_date_month` - **71.30% populated** (13,610/19,089 records)

2. **Priority 2 - Relationships & Classifications**
   - Array columns (amending, amended_by, etc.) - Important for legislation relationships
   - JSONB role columns (duty_holder, power_holder, etc.) - Key for role-based features
   - `geo_extent`, `geo_region`, `geo_country` - Important for geographic filtering

3. **Priority 3 - Content & External References**
   - `body`, `schedule`, `attachment` - Full text content
   - `leg_gov_uk_url` - External reference links
   - Article/clause reference columns - For detailed citation features

4. **Priority 4 - Metrics & Flags**
   - Count columns (△_#_amd_by_law, etc.) - For analytics
   - Boolean flags (is_amending, is_rescinding, etc.) - For filtering

## Import Script Locations

### Priority 1 Metadata Import
The Priority 1 metadata import script is located at: `scripts/import_priority1_metadata.exs`

**Status**: ✅ **COMPLETED** - Successfully imported core metadata including `title_en`, `md_description`, `created_at`, and date fields.

To run Priority 1 import:
```bash
mix run scripts/import_priority1_metadata.exs
```

### Full Data Import  
The full UK LRT data import script is located at: `scripts/import_uk_lrt_data.exs`

**Status**: ✅ **COMPLETED** - Successfully imported basic UK LRT structure and identifiers.

To run full data import:
```bash
source .env && mix run scripts/import_uk_lrt_data.exs
```

### Connection Testing
Use the connection test script to verify Supabase connectivity:
```bash
mix run scripts/test_connections.exs
```

**Key Features:**
- Both scripts support batch imports (100 records per batch for stability)
- Connection pooling optimized for Supabase
- Progress reporting and error handling
- Can be modified to import specific columns by updating the `columns_to_import` list

**Import Progress:**
- ✅ **Basic Structure**: All 19,089 records with core identifiers
- ✅ **Priority 1 Metadata**: Title, description, and date information (70-85% populated)
- 🔄 **Next Phase**: Relationships, classifications, and content import