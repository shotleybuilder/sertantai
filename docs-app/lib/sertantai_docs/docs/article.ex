defmodule SertantaiDocs.Docs.Article do
  @moduledoc """
  Article resource for managing documentation content.
  Represents a documentation page with metadata and content path.
  """

  use Ash.Resource,
    domain: SertantaiDocs.Docs,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      description "Article title"
    end

    attribute :slug, :string do
      allow_nil? false
      description "URL-friendly identifier"
    end

    attribute :content_path, :string do
      allow_nil? false
      description "Path to markdown file relative to docs root"
    end

    attribute :category, :atom do
      constraints one_of: [:dev, :user, :api]
      description "Documentation category"
    end

    attribute :tags, {:array, :string} do
      default []
      description "Tags for organization and search"
    end

    attribute :view_count, :integer do
      default 0
      description "Number of times this article has been viewed"
    end

    attribute :last_modified, :utc_datetime do
      description "Last modification time of the source file"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :slug, :content_path, :category, :tags, :last_modified]
    end

    update :update do
      accept [:title, :content_path, :tags, :last_modified]
    end

    update :increment_views do
      change increment(:view_count, by: 1)
    end
  end

  identities do
    identity :unique_slug, [:slug] do
      pre_check_with SertantaiDocs.Docs
    end
  end

  code_interface do
    define :create, action: :create
    define :read_all, action: :read
    define :get_by_slug, action: :read, get_by: [:slug]
    define :update, action: :update
    define :increment_views, action: :increment_views
    define :destroy, action: :destroy
  end
end