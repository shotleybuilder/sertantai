# UK Legal Register and Tracker (UK LRT) Database Schema

## Overview
This document provides a comprehensive overview of the UK LRT database schema with 116+ columns designed for legal document tracking, applicability screening, and regulatory compliance management.

---

## 🎯 Core Identification Fields

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key - unique identifier for each legal record |
| `name` | text | Official citation/name of the legal instrument (e.g., "UK_uksi_2023_1164") |
| `title_en` | character varying | English title of the legal instrument |
| `acronym` | text | Common acronym or short reference |
| `old_style_number` | text | Legacy numbering system reference |

---

## 📋 Document Classification

| Column | Type | Description |
|--------|------|-------------|
| `type_code` | text | Legal document type code (uksi, ssi, wsi, nisr, etc.) |
| `type_desc` | text | Human-readable description of document type |
| `type_class` | text | Broader classification category |
| `2ndary_class` | character varying | Secondary classification for cross-categorization |
| `family` | text | Primary legal domain/sector (e.g., "💙 FIRE", "💙 HEALTH") |
| `family_ii` | text | Secondary legal domain for cross-sector regulations |

---

## 🗓️ Temporal Information

| Column | Type | Description |
|--------|------|-------------|
| `year` | smallint | Year of enactment |
| `number` | text | Sequential number within the year |
| `number_int` | integer | Integer version of number (generated, for sorting) |
| `md_date` | date | Official made/signed date |
| `md_date_year` | integer | Year extracted from made date |
| `md_date_month` | integer | Month extracted from made date |
| `md_made_date` | date | Alternative made date field |
| `md_enactment_date` | date | Date the law was enacted |
| `md_coming_into_force_date` | date | Date the law came into force |
| `md_dct_valid_date` | date | Document validity date |
| `md_restrict_start_date` | date | Start date for any restrictions |

---

## ⚖️ Legal Status & Lifecycle

| Column | Type | Description |
|--------|------|-------------|
| `live` | text | Current legal status (✔ In force, ❌ Revoked, ⭕ Part Revocation) |
| `live_description` | text | Detailed description of current status |
| `latest_change_date` | date | Most recent date of any change to the document |
| `latest_change_date_year` | smallint | Year of latest change |
| `latest_change_date_month` | smallint | Month of latest change |
| `latest_amend_date` | date | Date of most recent amendment |
| `latest_amend_date_year` | integer | Year of latest amendment (generated) |
| `latest_amend_date_month` | integer | Month of latest amendment (generated) |
| `latest_rescind_date` | date | Date of rescission if applicable |
| `latest_rescind_date_year` | integer | Year of rescission (generated) |
| `latest_rescind_date_month` | integer | Month of rescission (generated) |

---

## 👥 Stakeholder Roles (JSONB Arrays)

| Column | Type | Description |
|--------|------|-------------|
| `role` | jsonb | General roles/duties imposed by this legislation |
| `duty_holder` | jsonb | Entities with specific duties under this law |
| `power_holder` | jsonb | Entities granted powers by this law |
| `rights_holder` | jsonb | Entities granted rights by this law |
| `responsibility_holder` | jsonb | Entities with responsibilities under this law |
| `role_gvt` | jsonb | Government roles and responsibilities |

---

## 📍 Geographic Scope

| Column | Type | Description |
|--------|------|-------------|
| `geo_extent` | text | Geographic extent of application |
| `geo_region` | text | Specific geographic regions covered |
| `geo_country` | jsonb | Countries where this law applies |
| `md_restrict_extent` | text | Any geographic restrictions |

---

## 🏷️ Categorization & Tagging

| Column | Type | Description |
|--------|------|-------------|
| `tags` | jsonb | Searchable tags for content categorization |
| `md_subjects` | jsonb | Subject matter classifications |
| `purpose` | jsonb | Legal purposes and objectives |
| `function` | jsonb | Functional classifications |
| `popimar` | jsonb | Population, Impact, or Market classifications |
| `si_code` | jsonb | Statutory Instrument codes |

---

## 📄 Document Structure & Content

| Column | Type | Description |
|--------|------|-------------|
| `md_description` | text | Detailed description of the legal instrument |
| `md_total_paras` | numeric(38,9) | Total number of paragraphs |
| `md_body_paras` | smallint | Number of body paragraphs |
| `md_schedule_paras` | smallint | Number of schedule paragraphs |
| `md_attachment_paras` | smallint | Number of attachment paragraphs |
| `md_images` | smallint | Number of images in the document |
| `md_change_log` | text | Change history log |

---

## 🔗 Legal Relationships & Cross-References

### Amendment Relationships
| Column | Type | Description |
|--------|------|-------------|
| `amending` | text[] | Laws that this instrument amends |
| `amended_by` | text[] | Laws that amend this instrument |
| `linked_amending` | text[] | Linked references to amendments made |
| `linked_amended_by` | text[] | Linked references to amendments received |
| `is_amending` | boolean | Flag indicating if this law amends others (generated) |
| `△_#_amd_by_law` | smallint | Count of laws amended by this one |
| `▽_#_amd_of_law` | smallint | Count of times this law was amended |

### Rescission/Revocation Relationships
| Column | Type | Description |
|--------|------|-------------|
| `rescinding` | text[] | Laws that this instrument rescinds |
| `rescinded_by` | text[] | Laws that rescind this instrument |
| `linked_rescinding` | text[] | Linked references to rescissions made |
| `linked_rescinded_by` | text[] | Linked references to rescissions received |
| `is_rescinding` | boolean | Flag indicating if this law rescinds others (generated) |
| `△_#_laws_rsc_law` | smallint | Count of laws this one rescinds |
| `▽_#_laws_rsc_law` | smallint | Count of laws that rescind this one |

### Enactment Relationships
| Column | Type | Description |
|--------|------|-------------|
| `enacting` | text[] | Laws that this instrument enacts |
| `enacted_by` | text[] | Laws that enact this instrument |
| `linked_enacted_by` | text[] | Linked references to enacting laws |
| `is_enacting` | boolean | Flag indicating if this law enacts others (generated) |
| `enacted_by_description` | text | Description of enacting authority |

---

## 🔍 Article-Level References

| Column | Type | Description |
|--------|------|-------------|
| `article_role` | text | Specific article references for roles |
| `role_article` | text | Role definitions by article |
| `article_duty_holder` | text | Article references for duty holders |
| `duty_holder_article` | text | Duty holder definitions by article |
| `article_power_holder` | text | Article references for power holders |
| `power_holder_article` | text | Power holder definitions by article |
| `article_rights_holder` | text | Article references for rights holders |
| `rights_holder_article` | text | Rights holder definitions by article |
| `article_responsibility_holder` | character varying | Article references for responsibility holders |
| `responsibility_holder_article` | character varying | Responsibility definitions by article |

---

## 📋 Article Clause References

| Column | Type | Description |
|--------|------|-------------|
| `article_duty_holder_clause` | text | Specific clauses within articles for duty holders |
| `duty_holder_article_clause` | text | Duty holder clause references |
| `article_power_holder_clause` | text | Power holder clause references |
| `power_holder_article_clause` | text | Clause definitions for power holders |
| `article_rights_holder_clause` | character varying | Rights holder clause references |
| `rights_holder_article_clause` | character varying | Clause definitions for rights holders |
| `article_responsibility_holder_clause` | character varying | Responsibility clause references |
| `responsibility_holder_article_clause` | character varying | Clause definitions for responsibilities |
| `article_popimar_clause` | text | Population/Impact/Market clause references |
| `popimar_article_clause` | text | POPIMAR definitions by clause |

---

## 📊 Change Management & Tracking

| Column | Type | Description |
|--------|------|-------------|
| `amd_change_log` | text | Amendment change history |
| `rsc_change_log` | text | Rescission change history |
| `amd_by_change_log` | text | Changes made by other laws |
| `△_amd_short_desc` | text | Short description of amendments made |
| `△_amd_long_desc` | text | Detailed description of amendments made |
| `▽_amd_short_desc` | text | Short description of amendments received |
| `▽_amd_long_desc` | text | Detailed description of amendments received |
| `△_rsc_short_desc` | text | Short description of rescissions made |
| `△_rsc_long_desc` | text | Detailed description of rescissions made |
| `▽_rsc_short_desc` | text | Short description of rescissions received |
| `▽_rsc_long_desc` | text | Detailed description of rescissions received |

---

## 🔢 Statistical Counters

| Column | Type | Description |
|--------|------|-------------|
| `△_#_laws_amd_law` | smallint | Number of laws this instrument amends |
| `▽_#_laws_amd_law` | smallint | Number of laws that amend this instrument |
| `△_#_laws_amd_by_law` | smallint | Laws amended by this law counter |
| `△_#_self_amd_by_law` | smallint | Self-amendments counter |
| `▽_#_self_amd_of_law` | smallint | Times self-amended counter |

---

## 🌐 External References & URLs

| Column | Type | Description |
|--------|------|-------------|
| `leg_gov_uk_url` | text | Generated URL to legislation.gov.uk (generated field) |
| `__e_register` | text | External register reference |
| `__hs_register` | text | Health & Safety register reference |
| `__hr_register` | text | Human Rights register reference |

---

## 📈 Computed Fields

| Column | Type | Description |
|--------|------|-------------|
| `title_en_year` | text | Generated: title + year combination |
| `title_en_year_number` | text | Generated: title + year + number combination |
| `is_making` | numeric(38,9) | Indicator for law-making function |
| `is_commencing` | numeric(38,9) | Indicator for commencement function |
| `year__from_revoked_by__latest_date__` | numeric(38,9) | Year calculation from revocation date |
| `month__from_revoked_by__latest_date__` | numeric(38,9) | Month calculation from revocation date |

---

## ⏰ System Fields

| Column | Type | Description |
|--------|------|-------------|
| `created_at` | timestamp with time zone | Record creation timestamp |
| `revoked_by__latest_date__` | date | Latest revocation date |

---

## 🎯 Applicability Screening Key Fields

### Primary Screening Fields
- **Sector Matching**: `family`, `family_ii`, `tags`, `md_subjects`
- **Role/Duty Matching**: `role`, `duty_holder`, `power_holder`, `rights_holder`, `responsibility_holder`
- **Geographic Matching**: `geo_extent`, `geo_region`, `geo_country`
- **Status Filtering**: `live`, `live_description`
- **Content Search**: `md_description`, `title_en`, `tags`

### Relationship Analysis
- **Impact Assessment**: Amendment and rescission arrays for understanding law evolution
- **Authority Mapping**: Article and clause references for precise obligation identification
- **Temporal Relevance**: Date fields for determining current applicability

---

## 📋 Database Indexes & Constraints

### Primary Key
- `uk_lrt_pkey`: PRIMARY KEY on `id` (uuid)

### Unique Constraints
- `uk_lrt_name_key`: UNIQUE on `name` field

### Row Level Security Policies
- Anonymous access to recent changes (180 days)
- Full read access for authenticated users
- Insert/update restricted to @spongl.com domain

---

*This schema represents a comprehensive legal document tracking system with rich metadata for applicability screening, stakeholder identification, and regulatory compliance analysis.*