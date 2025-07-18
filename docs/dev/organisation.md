# Organization Schema for Environmental, Safety & Human Resources Law Applicability

## Overview
This schema defines the comprehensive set of organization properties required for accurate applicability screening of environmental, safety, and human resources legislation. These properties map to various UK LRT database fields and enable sophisticated matching algorithms.

---

## 🏢 Basic Organization Information

### Core Identity
| Property | Type | Description | Legal Relevance |
|----------|------|-------------|-----------------|
| `organization_name` | string | Official registered name | Legal entity identification |
| `trading_names` | string[] | Known trading/brand names | Alternative entity references |
| `organization_type` | enum | Legal structure type | Determines applicable regulatory frameworks |
| `registration_number` | string | Companies House/regulatory number | Official entity verification |
| `vat_number` | string | VAT registration number | Tax and commercial law obligations |
| `charity_number` | string | Charity commission number (if applicable) | Charity-specific regulations |

### Organization Type Classifications
```
- limited_company
- public_limited_company  
- partnership
- limited_liability_partnership
- sole_trader
- charity
- community_interest_company
- public_sector_organization
- local_authority
- nhs_trust
- educational_institution
- housing_association
- cooperative
- trade_union
```

---

## 📍 Geographic & Operational Scope

### Location Details
| Property | Type | Description | Maps to UK LRT Field |
|----------|------|-------------|---------------------|
| `headquarters_country` | enum | Primary country of operation | `geo_country` |
| `headquarters_region` | enum | UK region/devolved nation | `geo_region` |
| `operational_countries` | string[] | All countries of operation | `geo_country` matching |
| `operational_regions` | string[] | UK regions with operations | `geo_region` matching |
| `operational_extent` | enum | Geographic scope classification | `geo_extent` |

### Geographic Scope Classifications
```
- england_only
- wales_only  
- scotland_only
- northern_ireland_only
- england_and_wales
- great_britain
- united_kingdom
- uk_and_overseas_territories
- international
```

---

## 👥 Workforce & Employment

### Employee Demographics
| Property | Type | Description | Legal Threshold Relevance |
|----------|------|-------------|---------------------------|
| `total_employees` | integer | Total number of employees | Size-based regulations (5+, 50+, 250+, 500+) |
| `full_time_employees` | integer | Full-time equivalent count | Working time regulations |
| `part_time_employees` | integer | Part-time employee count | Part-time worker protections |
| `temporary_employees` | integer | Temporary/contract workers | Agency worker regulations |
| `apprentices` | integer | Number of apprentices | Apprenticeship levy requirements |
| `volunteers` | integer | Number of volunteers | Volunteer-specific protections |

### Employment Categories
| Property | Type | Description | Regulatory Relevance |
|----------|------|-------------|---------------------|
| `has_young_workers` | boolean | Employs workers under 18 | Young worker protections |
| `has_night_workers` | boolean | Employs night shift workers | Night work regulations |
| `has_shift_workers` | boolean | Operates shift patterns | Shift work health regulations |
| `has_remote_workers` | boolean | Remote/homeworking arrangements | Remote work safety duties |
| `has_drivers` | boolean | Employs professional drivers | Driver working time rules |
| `has_security_staff` | boolean | Employs security personnel | Security industry regulations |

### Employment Practices
| Property | Type | Description | HR Law Relevance |
|----------|------|-------------|------------------|
| `collective_bargaining` | boolean | Recognizes trade unions | Collective consultation rights |
| `recognized_unions` | string[] | List of recognized trade unions | Industrial relations law |
| `consultation_arrangements` | enum | Employee consultation methods | Information & consultation regs |
| `equality_monitoring` | boolean | Conducts equality monitoring | Equality Act compliance |
| `flexible_working_policy` | boolean | Offers flexible working | Flexible working rights |

---

## 🏭 Industry & Sector Classification

### Primary Industry
| Property | Type | Description | Maps to UK LRT Field |
|----------|------|-------------|---------------------|
| `primary_sic_code` | string | Standard Industrial Classification | `family`, `tags` matching |
| `secondary_sic_codes` | string[] | Additional SIC codes | Cross-sector regulations |
| `industry_sector` | enum | High-level sector classification | `family` direct mapping |
| `business_activities` | string[] | Detailed business activities | `purpose`, `function` matching |

### Industry Sector Classifications (mapping to UK LRT `family` field)
```
- agriculture_forestry_fishing
- mining_quarrying  
- manufacturing
- electricity_gas_steam
- water_supply_sewerage
- construction
- wholesale_retail_trade
- transportation_storage
- accommodation_food_service
- information_communication
- financial_insurance
- real_estate
- professional_scientific_technical
- administrative_support_services
- public_administration_defence
- education
- human_health_social_work
- arts_entertainment_recreation
- other_service_activities
```

### Specific Regulated Activities
| Property | Type | Description | Regulatory Trigger |
|----------|------|-------------|-------------------|
| `handles_hazardous_substances` | boolean | Uses/stores hazardous materials | COSHH regulations |
| `food_handling` | boolean | Handles food products | Food safety regulations |
| `medical_activities` | boolean | Provides medical/healthcare services | Healthcare regulations |
| `financial_services` | boolean | Provides financial services | Financial conduct regulations |
| `data_processing` | boolean | Processes personal data | Data protection regulations |
| `environmental_permits_required` | boolean | Requires environmental permits | Environmental regulations |

---

## ⚡ Health & Safety Risk Profile

### Workplace Hazards
| Property | Type | Description | Safety Regulation Trigger |
|----------|------|-------------|--------------------------|
| `high_risk_activities` | string[] | List of high-risk activities | Specific safety regulations |
| `uses_machinery` | boolean | Operates industrial machinery | Machinery safety regulations |
| `height_work` | boolean | Work at height activities | Working at height regulations |
| `confined_spaces` | boolean | Work in confined spaces | Confined space regulations |
| `lone_working` | boolean | Employees work alone | Lone worker protections |
| `manual_handling` | boolean | Manual handling activities | Manual handling regulations |
| `display_screen_equipment` | boolean | Uses computer workstations | DSE regulations |

### Hazardous Substances & Processes
| Property | Type | Description | Specific Regulations |
|----------|------|-------------|---------------------|
| `hazardous_chemicals` | string[] | Types of chemicals used | COSHH, REACH compliance |
| `radioactive_materials` | boolean | Uses radioactive substances | Radiation protection regulations |
| `biological_agents` | boolean | Exposure to biological hazards | Biological agents regulations |
| `noise_exposure` | boolean | High noise environment | Noise at work regulations |
| `vibration_exposure` | boolean | Hand-arm/whole-body vibration | Vibration regulations |
| `temperature_extremes` | boolean | Extreme hot/cold working | Temperature-related protections |

### Safety Management
| Property | Type | Description | Management System Requirements |
|----------|------|-------------|-------------------------------|
| `safety_management_system` | boolean | Has formal SMS | Safety management obligations |
| `safety_representatives` | boolean | Appointed safety reps | Safety representative rights |
| `safety_committees` | boolean | Has safety committees | Safety committee regulations |
| `accident_reporting_system` | boolean | Formal accident reporting | RIDDOR compliance |
| `emergency_procedures` | boolean | Emergency response plans | Emergency planning requirements |

---

## 🌍 Environmental Impact Profile

### Environmental Activities
| Property | Type | Description | Environmental Regulation |
|----------|------|-------------|-------------------------|
| `waste_production` | enum | Level of waste generation | Waste management duties |
| `waste_types` | string[] | Types of waste produced | Specific waste stream regulations |
| `emissions_to_air` | boolean | Air emissions | Air quality regulations |
| `emissions_to_water` | boolean | Water discharges | Water pollution prevention |
| `contaminated_land` | boolean | Operates on contaminated land | Contaminated land regulations |
| `environmental_permits` | string[] | Required environmental permits | Permit-specific obligations |

### Resource Consumption
| Property | Type | Description | Sustainability Regulations |
|----------|------|-------------|---------------------------|
| `energy_consumption_high` | boolean | High energy consumption | Energy efficiency requirements |
| `water_consumption_high` | boolean | High water consumption | Water management duties |
| `carbon_reporting_required` | boolean | Must report carbon emissions | Carbon reporting regulations |
| `packaging_producer` | boolean | Produces packaging | Packaging waste regulations |
| `electrical_equipment` | boolean | WEEE producer | Electronic waste regulations |

---

## 🏢 Premises & Facilities

### Workplace Characteristics
| Property | Type | Description | Premises Regulations |
|----------|------|-------------|---------------------|
| `multi_occupancy_building` | boolean | Shares building with others | Shared premises duties |
| `public_access` | boolean | Public access to premises | Public safety obligations |
| `residential_accommodation` | boolean | Provides accommodation | Accommodation standards |
| `catering_facilities` | boolean | On-site catering | Food hygiene regulations |
| `parking_facilities` | boolean | Provides parking | Parking-related duties |

### Building & Fire Safety
| Property | Type | Description | Fire Safety Regulations |
|----------|------|-------------|------------------------|
| `building_height_storeys` | integer | Number of storeys | High-rise building regulations |
| `building_capacity` | integer | Maximum occupancy | Capacity-based fire safety |
| `fire_risk_category` | enum | Fire risk assessment level | Fire safety management |
| `means_of_escape` | boolean | Multiple escape routes | Escape route requirements |
| `fire_detection_systems` | boolean | Automated fire detection | Detection system maintenance |

---

## 💰 Financial & Economic Factors

### Financial Thresholds
| Property | Type | Description | Regulation Trigger |
|----------|------|-------------|-------------------|
| `annual_turnover` | integer | Annual revenue (£) | Size-based obligations |
| `balance_sheet_total` | integer | Total assets (£) | Large company definitions |
| `listed_company` | boolean | Publicly listed | Listed company requirements |
| `government_contracts` | boolean | Public sector contracts | Public procurement rules |
| `eu_funding` | boolean | Receives EU funding | EU compliance requirements |

### Financial Thresholds for Regulation
```
- micro_entity: <£632k turnover, <£316k balance sheet
- small_company: <£10.2m turnover, <£5.1m balance sheet  
- medium_company: <£36m turnover, <£18m balance sheet
- large_company: ≥£36m turnover or ≥£18m balance sheet
- public_interest_entity: Listed/banking/insurance
```

---

## 🎯 Stakeholder Roles & Responsibilities

### Key Personnel (maps to UK LRT `duty_holder`, `responsibility_holder` fields)
| Property | Type | Description | Legal Duty Relevance |
|----------|------|-------------|---------------------|
| `directors` | object[] | Company directors | Director duties |
| `health_safety_officers` | object[] | H&S responsible persons | Safety management duties |
| `data_protection_officer` | boolean | Has DPO | GDPR compliance |
| `money_laundering_officer` | boolean | Has MLRO | Financial crime prevention |
| `fire_safety_responsible_person` | object[] | Fire safety duties | Fire safety management |
| `first_aid_personnel` | integer | Number of first aiders | First aid provision |

### Competent Persons
| Property | Type | Description | Competency Requirements |
|----------|------|-------------|-------------------------|
| `appointed_competent_persons` | string[] | Areas of competence | Competent person duties |
| `professional_advisers` | string[] | External professional support | Advisory relationship duties |
| `training_providers` | string[] | Training delivery arrangements | Training provision obligations |

---

## 🔗 Relationships & Dependencies

### Supply Chain
| Property | Type | Description | Supply Chain Law |
|----------|------|-------------|------------------|
| `major_suppliers` | string[] | Key suppliers | Supply chain due diligence |
| `international_suppliers` | boolean | Overseas suppliers | Import/customs obligations |
| `subcontractors` | boolean | Uses subcontractors | Contractor management duties |
| `agency_workers` | boolean | Uses agency staff | Agency worker regulations |

### Customer Base
| Property | Type | Description | Consumer Law Relevance |
|----------|------|-------------|------------------------|
| `b2b_customers` | boolean | Business customers | B2B relationship law |
| `b2c_customers` | boolean | Consumer customers | Consumer protection law |
| `vulnerable_customers` | boolean | Serves vulnerable groups | Enhanced protection duties |
| `international_customers` | boolean | Overseas customers | Export/jurisdiction issues |

---

## ⏰ Temporal & Operational Patterns

### Operating Patterns
| Property | Type | Description | Working Time Relevance |
|----------|------|-------------|------------------------|
| `24_7_operations` | boolean | Round-the-clock operations | Continuous operation rules |
| `seasonal_operations` | boolean | Seasonal activity patterns | Seasonal worker protections |
| `shift_patterns` | string[] | Types of shift work | Shift work regulations |
| `on_call_arrangements` | boolean | On-call staff | On-call time regulations |

### Business Lifecycle
| Property | Type | Description | Lifecycle Regulation |
|----------|------|-------------|---------------------|
| `startup_phase` | boolean | Recently established | Startup support/obligations |
| `growth_phase` | boolean | Rapidly expanding | Growth-related compliance |
| `restructuring` | boolean | Undergoing restructuring | Restructuring consultation |
| `merger_acquisition` | boolean | M&A activity | Transfer of undertakings |

---

## 📊 Compliance & Risk Management

### Existing Compliance Framework
| Property | Type | Description | Compliance Overlap |
|----------|------|-------------|-------------------|
| `iso_certifications` | string[] | ISO standards achieved | Standards-based obligations |
| `industry_accreditations` | string[] | Industry-specific accreditations | Sector compliance |
| `regulatory_approvals` | string[] | Required regulatory approvals | Approval-specific duties |
| `insurance_requirements` | string[] | Mandatory insurance types | Insurance-driven obligations |

### Risk Management
| Property | Type | Description | Risk-Based Regulation |
|----------|------|-------------|----------------------|
| `risk_assessment_frequency` | enum | How often risks assessed | Risk management duties |
| `incident_history` | boolean | Previous incidents/prosecutions | Enhanced scrutiny trigger |
| `compliance_monitoring` | boolean | Active compliance monitoring | Monitoring obligations |
| `third_party_audits` | boolean | External audit requirements | Audit-based compliance |

---

## 🎯 AI Applicability Matching Strategy

### Primary Matching Fields
1. **Sector Classification**: `primary_sic_code` → `family` field matching
2. **Organization Size**: `total_employees`, `annual_turnover` → threshold-based filtering  
3. **Geographic Scope**: `operational_extent` → `geo_extent` matching
4. **Role Identification**: Key personnel → `duty_holder`, `responsibility_holder` matching
5. **Risk Profile**: Hazardous activities → specific regulation triggers

### Multi-Layer Matching Algorithm
```
Layer 1: Hard Constraints
- Geographic applicability (geo_extent)
- Legal status (live = "✔ In force")
- Organization type compatibility

Layer 2: Sector Matching  
- Primary SIC code → family mapping
- Business activities → tags/purpose matching
- Industry-specific triggers

Layer 3: Size & Threshold Matching
- Employee count thresholds
- Turnover-based obligations  
- Capacity/facility size triggers

Layer 4: Role & Responsibility Matching
- Key personnel → duty_holder matching
- Competent persons → responsibility_holder
- Management structure → power_holder

Layer 5: Activity-Specific Matching
- Hazardous activities → specific regulations
- Special processes → targeted obligations
- Risk profile → enhanced requirements
```

---

## 📋 Schema Implementation Notes

### Data Collection Strategy
- **Progressive profiling**: Collect essential data first, enhance over time
- **Conditional logic**: Show relevant fields based on organization type/sector
- **Validation rules**: Ensure data consistency and completeness
- **Regular updates**: Capture changes in organization profile

### Integration Points
- **Companies House API**: Automatic company data retrieval
- **SIC code lookup**: Standard classification validation
- **Postcode validation**: Geographic scope determination
- **Industry databases**: Sector-specific data enhancement

---

*This organization schema provides the foundation for sophisticated applicability screening by capturing the comprehensive range of factors that determine which environmental, safety, and human resources laws apply to specific organizations.*