defmodule Sertantai.Billing.Customer do
  @moduledoc """
  Billing customer resource linked to User accounts.
  
  Stores Stripe customer information and billing details.
  """
  
  use Ash.Resource,
    domain: Sertantai.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshGraphql.Resource
    ]

  postgres do
    table "billing_customers"
    repo Sertantai.Repo
    
    custom_indexes do
      index [:stripe_customer_id], unique: true
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :user_id, :uuid do
      allow_nil? false
      description "Reference to the User account"
    end
    
    attribute :stripe_customer_id, :string do
      allow_nil? false
      description "Stripe Customer ID"
    end
    
    attribute :email, :ci_string do
      allow_nil? false
      description "Customer email address"
    end
    
    attribute :name, :string do
      allow_nil? true
      description "Customer full name"
    end
    
    attribute :company, :string do
      allow_nil? true
      description "Customer company name"
    end
    
    attribute :phone, :string do
      allow_nil? true
      description "Customer phone number"
    end
    
    attribute :address, :map do
      allow_nil? true
      description "Customer billing address"
    end
    
    attribute :tax_id, :string do
      allow_nil? true
      description "Customer tax ID for invoicing"
    end
    
    attribute :metadata, :map do
      allow_nil? false
      default %{}
      description "Additional customer metadata"
    end

    timestamps()
  end

  identities do
    identity :unique_stripe_customer_id, [:stripe_customer_id]
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:user_id, :stripe_customer_id, :email, :name, :company, :phone, :address, :tax_id, :metadata]
    end
    
    update :update do
      primary? true
      accept [:email, :name, :company, :phone, :address, :tax_id, :metadata]
    end
    
    update :update_stripe_data do
      accept [:stripe_customer_id, :email, :name, :company, :phone, :address, :tax_id]
    end
  end

  relationships do
    belongs_to :user, Sertantai.Accounts.User do
      attribute_writable? false
      source_attribute :user_id
      destination_attribute :id
    end
    
    has_many :subscriptions, Sertantai.Billing.Subscription
    has_many :payments, Sertantai.Billing.Payment
  end

  policies do
    # Admin users can manage all customers
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Admin and support can read all customers
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :support)
    end
  end

  graphql do
    type :billing_customer

    queries do
      read_one :billing_customer, :read
      list :billing_customers, :read
    end

    mutations do
      create :create_billing_customer, :create
      update :update_billing_customer, :update
      destroy :destroy_billing_customer, :destroy
    end
  end
end