defmodule Sertantai.Repo.Migrations.AddFunctionAwareIndexes do
  @moduledoc """
  Phase 2 function-aware performance optimization indexes.
  Critical indexes for filtering to 'Making' function duty-creating laws only.
  """
  
  use Ecto.Migration
  
  # Disable transaction for concurrent index creation
  @disable_ddl_transaction true
  @disable_migration_lock true
  
  def up do
    # Critical function-based index for maximum performance optimization
    # Only index records with 'Making' function for duty-creating laws
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_uk_lrt_function_making 
    ON uk_lrt USING gin(function) 
    WHERE function ? 'Making';
    """
    
    # Enhanced GIN indexes for JSONB fields used in Phase 2 queries
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_uk_lrt_duty_holder_gin 
    ON uk_lrt USING gin(duty_holder);
    """
    
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_uk_lrt_role_gin 
    ON uk_lrt USING gin(role);
    """
    
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_uk_lrt_purpose_gin 
    ON uk_lrt USING gin(purpose);
    """
    
    # Composite index optimized for function-first queries
    # Only index 'Making' function records for maximum efficiency
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_uk_lrt_function_composite 
    ON uk_lrt(family, geo_extent, live) 
    WHERE function ? 'Making';
    """
    
    # Organization profile GIN index for Phase 2 extended attributes
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_organizations_profile_gin 
    ON organizations USING gin(core_profile);
    """
  end
  
  def down do
    execute "DROP INDEX IF EXISTS idx_uk_lrt_function_making;"
    execute "DROP INDEX IF EXISTS idx_uk_lrt_duty_holder_gin;"
    execute "DROP INDEX IF EXISTS idx_uk_lrt_role_gin;"
    execute "DROP INDEX IF EXISTS idx_uk_lrt_purpose_gin;"
    execute "DROP INDEX IF EXISTS idx_uk_lrt_function_composite;"
    execute "DROP INDEX IF EXISTS idx_organizations_profile_gin;"
  end
end