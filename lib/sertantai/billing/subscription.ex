defmodule Sertantai.Billing.Subscription do
  @moduledoc """
  Subscription resource for managing user subscriptions.
  
  Links customers to plans and tracks subscription lifecycle.
  """
  
  use Ash.Resource,
    domain: Sertantai.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshGraphql.Resource
    ]

  postgres do
    table "billing_subscriptions"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :customer_id, :uuid do
      allow_nil? false
      description "Reference to the billing customer"
    end
    
    attribute :plan_id, :uuid do
      allow_nil? false
      description "Reference to the subscription plan"
    end
    
    attribute :stripe_subscription_id, :string do
      allow_nil? false
      description "Stripe Subscription ID"
    end
    
    attribute :status, :atom do
      allow_nil? false
      constraints [one_of: [:active, :canceled, :incomplete, :incomplete_expired, :past_due, :trialing, :unpaid]]
      description "Subscription status from Stripe"
    end
    
    attribute :current_period_start, :utc_datetime do
      allow_nil? false
      description "Start of current billing period"
    end
    
    attribute :current_period_end, :utc_datetime do
      allow_nil? false
      description "End of current billing period"
    end
    
    attribute :cancel_at_period_end, :boolean do
      allow_nil? false
      default false
      description "Whether subscription will cancel at period end"
    end
    
    attribute :canceled_at, :utc_datetime do
      allow_nil? true
      description "When subscription was canceled"
    end
    
    attribute :trial_start, :utc_datetime do
      allow_nil? true
      description "Start of trial period"
    end
    
    attribute :trial_end, :utc_datetime do
      allow_nil? true
      description "End of trial period"
    end
    
    attribute :quantity, :integer do
      allow_nil? false
      default 1
      description "Number of seats/licenses"
    end
    
    attribute :metadata, :map do
      allow_nil? false
      default %{}
      description "Additional subscription metadata"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:customer_id, :plan_id, :stripe_subscription_id, :status, :current_period_start, :current_period_end, :cancel_at_period_end, :canceled_at, :trial_start, :trial_end, :quantity, :metadata]
    end
    
    update :update do
      primary? true
      accept [:status, :current_period_start, :current_period_end, :cancel_at_period_end, :canceled_at, :trial_start, :trial_end, :quantity, :metadata]
    end
    
    update :update_from_stripe do
      accept [:status, :current_period_start, :current_period_end, :cancel_at_period_end, :canceled_at, :trial_start, :trial_end, :quantity]
    end
    
    update :cancel do
      accept []
      change set_attribute(:status, :canceled)
      change set_attribute(:canceled_at, &DateTime.utc_now/0)
    end
    
    update :reactivate do
      accept []
      change set_attribute(:status, :active)
      change set_attribute(:canceled_at, nil)
      change set_attribute(:cancel_at_period_end, false)
    end
  end

  relationships do
    belongs_to :customer, Sertantai.Billing.Customer do
      attribute_writable? false
      source_attribute :customer_id
      destination_attribute :id
    end
    
    belongs_to :plan, Sertantai.Billing.Plan do
      attribute_writable? false
      source_attribute :plan_id
      destination_attribute :id
    end
    
    has_many :payments, Sertantai.Billing.Payment
  end

  policies do
    # Admin users can manage all subscriptions
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Admin and support can read all subscriptions
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :support)
    end
  end

  graphql do
    type :billing_subscription

    queries do
      read_one :billing_subscription, :read
      list :billing_subscriptions, :read
    end

    mutations do
      create :create_billing_subscription, :create
      update :update_billing_subscription, :update
      destroy :destroy_billing_subscription, :destroy
    end
  end
end