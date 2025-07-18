defmodule Sertantai.Billing.Plan do
  @moduledoc """
  Subscription plan resource for different pricing tiers.
  
  Defines the available subscription plans with their features and pricing.
  """
  
  use Ash.Resource,
    domain: Sertantai.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshGraphql.Resource
    ]

  postgres do
    table "billing_plans"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :name, :string do
      allow_nil? false
      description "Plan name (e.g., 'Professional', 'Enterprise')"
    end
    
    attribute :stripe_price_id, :string do
      allow_nil? false
      description "Stripe Price ID for this plan"
    end
    
    attribute :amount, :decimal do
      allow_nil? false
      description "Plan price in cents (e.g., 2999 for $29.99)"
    end
    
    attribute :currency, :string do
      allow_nil? false
      default "usd"
      description "Currency code (e.g., 'usd', 'eur')"
    end
    
    attribute :interval, :atom do
      allow_nil? false
      constraints [one_of: [:month, :year]]
      default :month
      description "Billing interval"
    end
    
    attribute :features, {:array, :string} do
      allow_nil? false
      default []
      description "List of features included in this plan"
    end
    
    attribute :user_role, :atom do
      allow_nil? false
      constraints [one_of: [:member, :professional, :admin, :support]]
      description "User role granted by this subscription"
    end
    
    attribute :active, :boolean do
      allow_nil? false
      default true
      description "Whether this plan is available for new subscriptions"
    end
    
    attribute :trial_days, :integer do
      allow_nil? true
      description "Number of trial days for this plan"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:name, :stripe_price_id, :amount, :currency, :interval, :features, :user_role, :active, :trial_days]
    end
    
    update :update do
      primary? true
      accept [:name, :stripe_price_id, :amount, :currency, :interval, :features, :user_role, :active, :trial_days]
    end
    
    update :activate do
      accept []
      change set_attribute(:active, true)
    end
    
    update :deactivate do
      accept []
      change set_attribute(:active, false)
    end
  end

  relationships do
    has_many :subscriptions, Sertantai.Billing.Subscription
  end

  policies do
    # Admin users can manage all plans
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Admin and support can read all plans
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :support)
    end
  end

  graphql do
    type :billing_plan

    queries do
      read_one :billing_plan, :read
      list :billing_plans, :read
    end

    mutations do
      create :create_billing_plan, :create
      update :update_billing_plan, :update
      destroy :destroy_billing_plan, :destroy
    end
  end
end