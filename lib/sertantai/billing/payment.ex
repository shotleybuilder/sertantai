defmodule Sertantai.Billing.Payment do
  @moduledoc """
  Payment resource for tracking transaction history.
  
  Records all payment attempts, successes, and failures.
  """
  
  use Ash.Resource,
    domain: Sertantai.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshGraphql.Resource
    ]

  postgres do
    table "billing_payments"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :customer_id, :uuid do
      allow_nil? false
      description "Reference to the billing customer"
    end
    
    attribute :subscription_id, :uuid do
      allow_nil? true
      description "Reference to the subscription (if applicable)"
    end
    
    attribute :stripe_payment_intent_id, :string do
      allow_nil? true
      description "Stripe Payment Intent ID"
    end
    
    attribute :stripe_invoice_id, :string do
      allow_nil? true
      description "Stripe Invoice ID"
    end
    
    attribute :amount, :decimal do
      allow_nil? false
      description "Payment amount in cents"
    end
    
    attribute :currency, :string do
      allow_nil? false
      default "usd"
      description "Currency code"
    end
    
    attribute :status, :atom do
      allow_nil? false
      constraints [one_of: [:pending, :succeeded, :failed, :canceled, :requires_action]]
      description "Payment status"
    end
    
    attribute :failure_reason, :string do
      allow_nil? true
      description "Reason for payment failure"
    end
    
    attribute :payment_method, :string do
      allow_nil? true
      description "Payment method used (e.g., 'card', 'bank_transfer')"
    end
    
    attribute :description, :string do
      allow_nil? true
      description "Payment description"
    end
    
    attribute :metadata, :map do
      allow_nil? false
      default %{}
      description "Additional payment metadata"
    end
    
    attribute :processed_at, :utc_datetime do
      allow_nil? true
      description "When payment was processed"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:customer_id, :subscription_id, :stripe_payment_intent_id, :stripe_invoice_id, :amount, :currency, :status, :failure_reason, :payment_method, :description, :metadata, :processed_at]
    end
    
    update :update do
      primary? true
      accept [:status, :failure_reason, :payment_method, :description, :metadata, :processed_at]
    end
    
    update :mark_succeeded do
      accept []
      change set_attribute(:status, :succeeded)
      change set_attribute(:processed_at, &DateTime.utc_now/0)
    end
    
    update :mark_failed do
      accept [:failure_reason]
      change set_attribute(:status, :failed)
      change set_attribute(:processed_at, &DateTime.utc_now/0)
    end
  end

  relationships do
    belongs_to :customer, Sertantai.Billing.Customer do
      attribute_writable? false
      source_attribute :customer_id
      destination_attribute :id
    end
    
    belongs_to :subscription, Sertantai.Billing.Subscription do
      attribute_writable? false
      source_attribute :subscription_id
      destination_attribute :id
    end
  end

  policies do
    # Admin users can manage all payments
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Admin and support can read all payments
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :support)
    end
  end

  graphql do
    type :billing_payment

    queries do
      read_one :billing_payment, :read
      list :billing_payments, :read
    end

    mutations do
      create :create_billing_payment, :create
      update :update_billing_payment, :update
      destroy :destroy_billing_payment, :destroy
    end
  end
end