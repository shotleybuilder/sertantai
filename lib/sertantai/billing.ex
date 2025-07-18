defmodule Sertantai.Billing do
  @moduledoc """
  Billing domain for Sertantai application.
  
  Manages subscription billing, customer management, and payment processing
  using Stripe integration with automatic role-based access control.
  """
  
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  resources do
    resource Sertantai.Billing.Customer
    resource Sertantai.Billing.Plan
    resource Sertantai.Billing.Subscription
    resource Sertantai.Billing.Payment
  end

  authorization do
    require_actor? true
  end

  graphql do
    authorize? true
  end
end