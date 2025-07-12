defmodule Sertantai.Repo.Migrations.AlignUkLrtWithProductionSchema do
  @moduledoc """
  Adds missing columns to uk_lrt table to align with production schema.
  
  SAFETY NOTES:
  - This migration only ADDS columns, never drops or modifies existing ones
  - All new columns are nullable to avoid breaking existing data
  - Preserves all 19K+ existing records
  - Uses simple ADD statements without conditional logic for safety
  """
  
  use Ecto.Migration

  def up do
    # Core Identification Fields (some already exist: id, name)
    alter table(:uk_lrt) do
      add :title_en, :text
      add :acronym, :text
      add :old_style_number, :text
    end
    
    # Document Classification (family already exists)
    alter table(:uk_lrt) do
      add :type_code, :text
      add :type_class, :text
      add :"2ndary_class", :string
    end
    
    # Temporal Information (year, number already exist)
    alter table(:uk_lrt) do
      add :number_int, :integer
      add :md_date, :date
      add :md_date_year, :integer
      add :md_date_month, :integer
      add :md_made_date, :date
      add :md_enactment_date, :date
      add :md_coming_into_force_date, :date
      add :md_dct_valid_date, :date
      add :md_restrict_start_date, :date
    end
    
    # Legal Status & Lifecycle (live already exists)
    alter table(:uk_lrt) do
      add :live_description, :text
      add :latest_change_date, :date
      add :latest_change_date_year, :smallint
      add :latest_change_date_month, :smallint
      add :latest_amend_date, :date
      add :latest_amend_date_year, :integer
      add :latest_amend_date_month, :integer
      add :latest_rescind_date, :date
      add :latest_rescind_date_year, :integer
      add :latest_rescind_date_month, :integer
    end
    
    # Stakeholder Roles (role already exists as array, add JSONB versions)
    alter table(:uk_lrt) do
      add :duty_holder, :jsonb
      add :power_holder, :jsonb
      add :rights_holder, :jsonb
      add :responsibility_holder, :jsonb
      add :role_gvt, :jsonb
    end
    
    # Geographic Scope
    alter table(:uk_lrt) do
      add :geo_extent, :text
      add :geo_region, :text
      add :geo_country, :jsonb
      add :md_restrict_extent, :text
    end
    
    # Categorization & Tagging (tags already exists as array)
    alter table(:uk_lrt) do
      add :md_subjects, :jsonb
      add :purpose, :jsonb
      add :function, :jsonb
      add :popimar, :jsonb
      add :si_code, :jsonb
    end
    
    # Document Structure & Content (md_description already exists)
    alter table(:uk_lrt) do
      add :md_total_paras, :decimal, precision: 38, scale: 9
      add :md_body_paras, :smallint
      add :md_schedule_paras, :smallint
      add :md_attachment_paras, :smallint
      add :md_images, :smallint
      add :md_change_log, :text
    end
    
    # Amendment relationships
    alter table(:uk_lrt) do
      add :amending, {:array, :text}
      add :amended_by, {:array, :text}
      add :linked_amending, {:array, :text}
      add :linked_amended_by, {:array, :text}
      add :is_amending, :boolean
      add :"△_#_amd_by_law", :smallint
      add :"▽_#_amd_of_law", :smallint
    end
    
    # Rescission relationships
    alter table(:uk_lrt) do
      add :rescinding, {:array, :text}
      add :rescinded_by, {:array, :text}
      add :linked_rescinding, {:array, :text}
      add :linked_rescinded_by, {:array, :text}
      add :is_rescinding, :boolean
      add :"△_#_laws_rsc_law", :smallint
      add :"▽_#_laws_rsc_law", :smallint
    end
    
    # Enactment relationships
    alter table(:uk_lrt) do
      add :enacting, {:array, :text}
      add :enacted_by, {:array, :text}
      add :linked_enacted_by, {:array, :text}
      add :is_enacting, :boolean
      add :enacted_by_description, :text
    end
    
    # Article-level references
    alter table(:uk_lrt) do
      add :article_role, :text
      add :role_article, :text
      add :article_duty_holder, :text
      add :duty_holder_article, :text
      add :article_power_holder, :text
      add :power_holder_article, :text
      add :article_rights_holder, :text
      add :rights_holder_article, :text
      add :article_responsibility_holder, :string
      add :responsibility_holder_article, :string
    end
    
    # Article clause references
    alter table(:uk_lrt) do
      add :article_duty_holder_clause, :text
      add :duty_holder_article_clause, :text
      add :article_power_holder_clause, :text
      add :power_holder_article_clause, :text
      add :article_rights_holder_clause, :string
      add :rights_holder_article_clause, :string
      add :article_responsibility_holder_clause, :string
      add :responsibility_holder_article_clause, :string
      add :article_popimar_clause, :text
      add :popimar_article_clause, :text
    end
    
    # Change management & tracking
    alter table(:uk_lrt) do
      add :amd_change_log, :text
      add :rsc_change_log, :text
      add :amd_by_change_log, :text
      add :"△_amd_short_desc", :text
      add :"△_amd_long_desc", :text
      add :"▽_amd_short_desc", :text
      add :"▽_amd_long_desc", :text
      add :"△_rsc_short_desc", :text
      add :"△_rsc_long_desc", :text
      add :"▽_rsc_short_desc", :text
      add :"▽_rsc_long_desc", :text
    end
    
    # Statistical counters
    alter table(:uk_lrt) do
      add :"△_#_laws_amd_law", :smallint
      add :"▽_#_laws_amd_law", :smallint
      add :"△_#_laws_amd_by_law", :smallint
      add :"△_#_self_amd_by_law", :smallint
      add :"▽_#_self_amd_of_law", :smallint
    end
    
    # External references & URLs
    alter table(:uk_lrt) do
      add :leg_gov_uk_url, :text
      add :__e_register, :text
      add :__hs_register, :text
      add :__hr_register, :text
    end
    
    # Computed fields
    alter table(:uk_lrt) do
      add :title_en_year, :text
      add :title_en_year_number, :text
      add :is_making, :decimal, precision: 38, scale: 9
      add :is_commencing, :decimal, precision: 38, scale: 9
      add :year__from_revoked_by__latest_date__, :decimal, precision: 38, scale: 9
      add :month__from_revoked_by__latest_date__, :decimal, precision: 38, scale: 9
      add :revoked_by__latest_date__, :date
    end
    
    # Create essential indexes for Phase 1 applicability matching
    # Use execute with IF NOT EXISTS to avoid errors if indexes already exist
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_live ON uk_lrt(live);"
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_family ON uk_lrt(family);"
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_geo_extent ON uk_lrt(geo_extent);"
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_duty_holder_gin ON uk_lrt USING gin(duty_holder);"
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_role_gin ON uk_lrt USING gin(role);"
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_tags_gin ON uk_lrt USING gin(tags);"
    
    # Compound index for Phase 1 queries
    execute "CREATE INDEX IF NOT EXISTS idx_uk_lrt_live_family_geo ON uk_lrt(live, family, geo_extent);"
    
    flush()
    
    IO.puts("✅ Migration completed successfully!")
    IO.puts("   - Added ~104 new columns to align with production schema")
    IO.puts("   - All existing records preserved")
    IO.puts("   - Essential indexes created for Phase 1 applicability matching")
    IO.puts("   - Note: Original 'role' and 'tags' columns remain as arrays for backward compatibility")
  end

  def down do
    # This rollback removes all added columns
    # WARNING: This will permanently delete any data in the added columns
    
    alter table(:uk_lrt) do
      # Remove in reverse order to avoid dependency issues
      remove :revoked_by__latest_date__
      remove :month__from_revoked_by__latest_date__
      remove :year__from_revoked_by__latest_date__
      remove :is_commencing
      remove :is_making
      remove :title_en_year_number
      remove :title_en_year
      
      remove :__hr_register
      remove :__hs_register
      remove :__e_register
      remove :leg_gov_uk_url
      
      remove :"▽_#_self_amd_of_law"
      remove :"△_#_self_amd_by_law"
      remove :"△_#_laws_amd_by_law"
      remove :"▽_#_laws_amd_law"
      remove :"△_#_laws_amd_law"
      
      remove :"▽_rsc_long_desc"
      remove :"▽_rsc_short_desc"
      remove :"△_rsc_long_desc"
      remove :"△_rsc_short_desc"
      remove :"▽_amd_long_desc"
      remove :"▽_amd_short_desc"
      remove :"△_amd_long_desc"
      remove :"△_amd_short_desc"
      remove :amd_by_change_log
      remove :rsc_change_log
      remove :amd_change_log
      
      remove :popimar_article_clause
      remove :article_popimar_clause
      remove :responsibility_holder_article_clause
      remove :article_responsibility_holder_clause
      remove :rights_holder_article_clause
      remove :article_rights_holder_clause
      remove :power_holder_article_clause
      remove :article_power_holder_clause
      remove :duty_holder_article_clause
      remove :article_duty_holder_clause
      
      remove :responsibility_holder_article
      remove :article_responsibility_holder
      remove :rights_holder_article
      remove :article_rights_holder
      remove :power_holder_article
      remove :article_power_holder
      remove :duty_holder_article
      remove :article_duty_holder
      remove :role_article
      remove :article_role
      
      remove :enacted_by_description
      remove :is_enacting
      remove :linked_enacted_by
      remove :enacted_by
      remove :enacting
      
      remove :"▽_#_laws_rsc_law"
      remove :"△_#_laws_rsc_law"
      remove :is_rescinding
      remove :linked_rescinded_by
      remove :linked_rescinding
      remove :rescinded_by
      remove :rescinding
      
      remove :"▽_#_amd_of_law"
      remove :"△_#_amd_by_law"
      remove :is_amending
      remove :linked_amended_by
      remove :linked_amending
      remove :amended_by
      remove :amending
      
      remove :md_change_log
      remove :md_images
      remove :md_attachment_paras
      remove :md_schedule_paras
      remove :md_body_paras
      remove :md_total_paras
      
      remove :si_code
      remove :popimar
      remove :function
      remove :purpose
      remove :md_subjects
      
      remove :md_restrict_extent
      remove :geo_country
      remove :geo_region
      remove :geo_extent
      
      remove :role_gvt
      remove :responsibility_holder
      remove :rights_holder
      remove :power_holder
      remove :duty_holder
      
      remove :latest_rescind_date_month
      remove :latest_rescind_date_year
      remove :latest_rescind_date
      remove :latest_amend_date_month
      remove :latest_amend_date_year
      remove :latest_amend_date
      remove :latest_change_date_month
      remove :latest_change_date_year
      remove :latest_change_date
      remove :live_description
      
      remove :md_restrict_start_date
      remove :md_dct_valid_date
      remove :md_coming_into_force_date
      remove :md_enactment_date
      remove :md_made_date
      remove :md_date_month
      remove :md_date_year
      remove :md_date
      remove :number_int
      
      remove :"2ndary_class"
      remove :type_class
      remove :type_code
      
      remove :old_style_number
      remove :acronym
      remove :title_en
    end
    
    IO.puts("⚠️  Rollback completed - schema reverted to original 12 columns")
  end
end