defmodule Sertantai.UkLrt do
  @moduledoc """
  UK LRT (Long Range Transport) Ash resource for managing transport records.
  Provides filtering and selection capabilities for family and family_ii fields.
  """
  
  use Ash.Resource,
    domain: Sertantai.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  postgres do
    table "uk_lrt"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id, writable?: false
    
    attribute :family, :string do
      allow_nil? true
      description "Primary family classification"
    end
    
    attribute :family_ii, :string do
      allow_nil? true
      description "Secondary family classification"
    end
    
    attribute :name, :string do
      allow_nil? true
      description "Record name or identifier"
    end
    
    attribute :md_description, :string do
      allow_nil? true
      description "Markdown description of the record"
    end
    
    attribute :year, :integer do
      allow_nil? true
      description "Year associated with the record"
    end
    
    attribute :number, :string do
      allow_nil? true
      description "Record number"
    end
    
    attribute :live, :string do
      allow_nil? true
      description "Live status"
    end
    
    attribute :type_desc, :string do
      allow_nil? true
      description "Type description"
    end
    
    attribute :role, {:array, :string} do
      allow_nil? true
      description "Role information as array of strings"
    end
    
    attribute :tags, {:array, :string} do
      allow_nil? true
      description "Tags as array of strings"
    end
    
    attribute :created_at, :utc_datetime do
      allow_nil? true
      description "Creation timestamp"
      writable? false
    end
    
    # Phase 1 Essential Fields for Applicability Matching
    attribute :title_en, :string do
      allow_nil? true
      description "English title of the legal instrument"
    end
    
    attribute :geo_extent, :string do
      allow_nil? true
      description "Geographic extent of application"
    end
    
    attribute :geo_region, :string do
      allow_nil? true
      description "Specific geographic regions covered"
    end
    
    attribute :duty_holder, :map do
      allow_nil? true
      description "Entities with specific duties under this law (JSONB)"
    end
    
    attribute :power_holder, :map do
      allow_nil? true
      description "Entities granted powers by this law (JSONB)"
    end
    
    attribute :rights_holder, :map do
      allow_nil? true
      description "Entities granted rights by this law (JSONB)"
    end
    
    attribute :purpose, :map do
      allow_nil? true
      description "Legal purposes and objectives (JSONB)"
    end
    
    attribute :latest_amend_date, :date do
      allow_nil? true
      description "Date of most recent amendment"
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    
    read :by_family do
      description "Filter records by family field"
      argument :family, :string, allow_nil?: false
      filter expr(family == ^arg(:family))
      pagination offset?: true, keyset?: true, default_limit: 20
    end
    
    read :by_family_ii do
      description "Filter records by family_ii field"
      argument :family_ii, :string, allow_nil?: false
      filter expr(family_ii == ^arg(:family_ii))
      pagination offset?: true, keyset?: true, default_limit: 20
    end
    
    read :by_families do
      description "Filter records by both family fields"
      argument :family, :string, allow_nil?: true
      argument :family_ii, :string, allow_nil?: true
      
      filter expr(
        if is_nil(^arg(:family)) do
          true
        else
          family == ^arg(:family)
        end and
        if is_nil(^arg(:family_ii)) do
          true
        else
          family_ii == ^arg(:family_ii)
        end
      )
    end
    
    read :paginated do
      description "Paginated read with optional filtering"
      argument :family, :string, allow_nil?: true
      argument :family_ii, :string, allow_nil?: true
      argument :page_size, :integer, default: 20
      
      filter expr(
        if is_nil(^arg(:family)) do
          true
        else
          family == ^arg(:family)
        end and
        if is_nil(^arg(:family_ii)) do
          true
        else
          family_ii == ^arg(:family_ii)
        end
      )
      
      pagination offset?: true, keyset?: true, default_limit: 20
    end
    
    read :distinct_families do
      description "Get distinct family values"
      
      prepare build(select: [:family], distinct: [:family])
    end
    
    read :distinct_family_ii do
      description "Get distinct family_ii values"
      
      prepare build(select: [:family_ii], distinct: [:family_ii])
      filter expr(not is_nil(family_ii))
    end
    
    read :for_sync do
      description "Get records formatted for sync operations"
      argument :record_ids, {:array, :string}, allow_nil?: false
      argument :format, :string, default: "standard"
      
      filter expr(id in ^arg(:record_ids))
      
      prepare build(
        select: [
          :id, :name, :family, :family_ii, :year, :number, 
          :live, :type_desc, :md_description, :tags, :role, :created_at
        ]
      )
    end
    
    read :sync_summary do
      description "Get summary statistics for sync preparation"
      argument :record_ids, {:array, :string}, allow_nil?: false
      
      filter expr(id in ^arg(:record_ids))
      
      prepare build(
        select: [:id, :family, :family_ii, :year, :live],
        load: [:display_name]
      )
    end
    
    # Phase 1 Applicability Matching Actions
    read :for_applicability_screening do
      description "Get records for basic applicability screening"
      argument :family, :string, allow_nil?: true
      argument :geo_extent, :string, allow_nil?: true
      argument :live_status, :string, default: "✔ In force"
      argument :limit, :integer, default: 100
      
      filter expr(
        live == ^arg(:live_status) and
        if is_nil(^arg(:family)) do
          true
        else
          family == ^arg(:family)
        end and
        if is_nil(^arg(:geo_extent)) do
          true
        else
          geo_extent == ^arg(:geo_extent)
        end
      )
      
      prepare build(
        select: [:id, :name, :title_en, :family, :geo_extent, :live, :year, :md_description, :duty_holder],
        sort: [year: :desc, latest_amend_date: :desc]
      )
      
      pagination offset?: true, default_limit: 100
    end
    
    read :count_for_screening do
      description "Count applicable records for screening"
      argument :family, :string, allow_nil?: true
      argument :geo_extent, :string, allow_nil?: true
      argument :live_status, :string, default: "✔ In force"
      
      filter expr(
        live == ^arg(:live_status) and
        if is_nil(^arg(:family)) do
          true
        else
          family == ^arg(:family)
        end and
        if is_nil(^arg(:geo_extent)) do
          true
        else
          geo_extent == ^arg(:geo_extent)
        end
      )
      
      prepare build(select: [:id])
    end
  end


  calculations do
    calculate :display_name, :string, expr(coalesce(name, fragment("CONCAT('Record #', ?)", id))) do
      description "Display name for the record"
    end
  end

  # GraphQL configuration
  graphql do
    type :uk_lrt_record
    
    queries do
      get :get_uk_lrt_record, :read
      list :list_uk_lrt_records, :read
      list :uk_lrt_by_family, :by_family
      list :uk_lrt_by_family_ii, :by_family_ii
      list :uk_lrt_by_families, :by_families
      list :uk_lrt_paginated, :paginated
      list :distinct_families, :distinct_families
      list :distinct_family_ii, :distinct_family_ii
    end
    
    mutations do
      create :create_uk_lrt_record, :create
      update :update_uk_lrt_record, :update
      destroy :destroy_uk_lrt_record, :destroy
    end
  end

  # JSON API configuration
  json_api do
    type "uk_lrt_record"
    
    routes do
      base "/api/uk_lrt"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end
end