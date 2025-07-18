defmodule Sertantai.BillingFixtures do
  @moduledoc """
  This module defines test helpers for creating billing-related entities.
  """
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription, Payment}
  alias Sertantai.AccountsFixtures
  
  def plan_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{
      name: "Test Plan #{System.unique_integer([:positive])}",
      stripe_price_id: "price_test_#{System.unique_integer([:positive])}",
      amount: 29.99,
      currency: "usd",
      interval: "month",
      user_role: "professional",
      active: true,
      features: ["Test Feature 1", "Test Feature 2"]
    })
    
    {:ok, plan} = Ash.create(Plan, attrs)
    plan
  end
  
  def customer_fixture(attrs \\ %{}) do
    user = attrs[:user] || AccountsFixtures.user_fixture()
    
    attrs = Enum.into(attrs, %{
      user_id: user.id,
      stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
      email: user.email,
      name: "Test Customer #{System.unique_integer([:positive])}",
      phone: "+1234567890",
      company: "Test Company"
    })
    
    {:ok, customer} = Ash.create(Customer, attrs)
    customer
  end
  
  def subscription_fixture(attrs \\ %{}) do
    customer = attrs[:customer] || customer_fixture()
    plan = attrs[:plan] || plan_fixture()
    
    now = DateTime.utc_now()
    
    attrs = Enum.into(attrs, %{
      customer_id: customer.id,
      plan_id: plan.id,
      stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
      status: "active",
      current_period_start: now,
      current_period_end: DateTime.add(now, 30, :day),
      cancel_at_period_end: false
    })
    
    {:ok, subscription} = Ash.create(Subscription, attrs)
    subscription
  end
  
  def payment_fixture(attrs \\ %{}) do
    customer = attrs[:customer] || customer_fixture()
    subscription = attrs[:subscription]
    
    attrs = Enum.into(attrs, %{
      customer_id: customer.id,
      subscription_id: subscription && subscription.id,
      amount: 29.99,
      currency: "usd",
      status: "succeeded",
      stripe_payment_intent_id: "pi_test_#{System.unique_integer([:positive])}",
      payment_method: "card",
      description: "Test payment",
      processed_at: DateTime.utc_now()
    })
    
    {:ok, payment} = Ash.create(Payment, attrs)
    payment
  end
  
  def active_subscription_fixture(attrs \\ %{}) do
    subscription_fixture(Map.put(attrs, :status, "active"))
  end
  
  def canceled_subscription_fixture(attrs \\ %{}) do
    attrs = attrs
      |> Map.put(:status, "canceled")
      |> Map.put(:canceled_at, DateTime.utc_now())
    
    subscription_fixture(attrs)
  end
  
  def failed_payment_fixture(attrs \\ %{}) do
    attrs = attrs
      |> Map.put(:status, "failed")
      |> Map.put(:failure_reason, "card_declined")
    
    payment_fixture(attrs)
  end
  
  def professional_plan_fixture(attrs \\ %{}) do
    attrs = attrs
      |> Map.put(:name, "Professional Plan")
      |> Map.put(:user_role, "professional")
      |> Map.put(:amount, 29.99)
    
    plan_fixture(attrs)
  end
  
  def enterprise_plan_fixture(attrs \\ %{}) do
    attrs = attrs
      |> Map.put(:name, "Enterprise Plan")
      |> Map.put(:user_role, "professional") # or "enterprise" if that role exists
      |> Map.put(:amount, 99.99)
    
    plan_fixture(attrs)
  end
  
  def complete_billing_setup_fixture(attrs \\ %{}) do
    user = attrs[:user] || AccountsFixtures.user_fixture()
    plan = attrs[:plan] || professional_plan_fixture()
    
    customer = customer_fixture(%{user: user})
    subscription = subscription_fixture(%{customer: customer, plan: plan})
    payment = payment_fixture(%{customer: customer, subscription: subscription})
    
    %{
      user: user,
      customer: customer,
      plan: plan,
      subscription: subscription,
      payment: payment
    }
  end
  
  def stripe_webhook_event_fixture(event_type, object_data \\ %{}) do
    %{
      "id" => "evt_#{System.unique_integer([:positive])}",
      "object" => "event",
      "api_version" => "2020-08-27",
      "created" => DateTime.utc_now() |> DateTime.to_unix(),
      "data" => %{
        "object" => object_data
      },
      "livemode" => false,
      "pending_webhooks" => 1,
      "request" => %{
        "id" => "req_#{System.unique_integer([:positive])}",
        "idempotency_key" => nil
      },
      "type" => event_type
    }
  end
  
  def subscription_created_event_fixture(subscription_data \\ %{}) do
    default_data = %{
      "id" => "sub_#{System.unique_integer([:positive])}",
      "object" => "subscription",
      "customer" => "cus_#{System.unique_integer([:positive])}",
      "status" => "active",
      "current_period_start" => DateTime.utc_now() |> DateTime.to_unix(),
      "current_period_end" => DateTime.add(DateTime.utc_now(), 30, :day) |> DateTime.to_unix(),
      "cancel_at_period_end" => false,
      "items" => %{
        "data" => [%{
          "price" => %{
            "id" => "price_#{System.unique_integer([:positive])}"
          }
        }]
      }
    }
    
    object_data = Map.merge(default_data, subscription_data)
    stripe_webhook_event_fixture("customer.subscription.created", object_data)
  end
  
  def payment_intent_succeeded_event_fixture(payment_data \\ %{}) do
    default_data = %{
      "id" => "pi_#{System.unique_integer([:positive])}",
      "object" => "payment_intent",
      "amount" => 2999,
      "currency" => "usd",
      "customer" => "cus_#{System.unique_integer([:positive])}",
      "payment_method_types" => ["card"],
      "status" => "succeeded",
      "description" => "Test payment"
    }
    
    object_data = Map.merge(default_data, payment_data)
    stripe_webhook_event_fixture("payment_intent.succeeded", object_data)
  end
end