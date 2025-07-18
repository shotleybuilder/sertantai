defmodule Sertantai.Billing.SubscriptionTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription}
  alias Sertantai.Accounts.User
  
  setup do
    # Create test user
    {:ok, user} = Ash.create(User, %{
      email: "sub@example.com",
      hashed_password: "hashedpassword123",
      role: :member
    })
    
    # Create test plan
    {:ok, plan} = Ash.create(Plan, %{
      name: "Test Plan",
      stripe_price_id: "price_test",
      amount: 29.99,
      currency: "usd",
      interval: "month",
      user_role: "professional"
    })
    
    # Create test customer
    {:ok, customer} = Ash.create(Customer, %{
      user_id: user.id,
      stripe_customer_id: "cus_sub_test",
      email: user.email
    })
    
    {:ok, user: user, plan: plan, customer: customer}
  end
  
  describe "Subscription resource" do
    test "creates a subscription", %{customer: customer, plan: plan} do
      attrs = %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_test123",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
        cancel_at_period_end: false
      }
      
      assert {:ok, subscription} = Ash.create(Subscription, attrs)
      assert subscription.customer_id == customer.id
      assert subscription.plan_id == plan.id
      assert subscription.stripe_subscription_id == "sub_test123"
      assert subscription.status == "active"
      assert subscription.cancel_at_period_end == false
    end
    
    test "loads customer and plan relationships", %{customer: customer, plan: plan} do
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_rel",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      loaded_subscription = Ash.load!(subscription, [:customer, :plan])
      assert loaded_subscription.customer.id == customer.id
      assert loaded_subscription.plan.id == plan.id
      assert loaded_subscription.plan.name == "Test Plan"
    end
    
    test "queries active subscriptions", %{customer: customer, plan: plan} do
      # Create active subscription
      {:ok, active_sub} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_active",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      # Create canceled subscription
      {:ok, canceled_sub} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_canceled",
        status: "canceled",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
        canceled_at: DateTime.utc_now()
      })
      
      active_subscriptions = Subscription
        |> Ash.Query.filter(status == "active")
        |> Ash.read!()
        
      assert Enum.any?(active_subscriptions, &(&1.id == active_sub.id))
      refute Enum.any?(active_subscriptions, &(&1.id == canceled_sub.id))
    end
    
    test "updates subscription status", %{customer: customer, plan: plan} do
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_update",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      assert {:ok, updated} = Ash.update(subscription, %{
        status: "canceled",
        cancel_at_period_end: true,
        canceled_at: DateTime.utc_now()
      })
      
      assert updated.status == "canceled"
      assert updated.cancel_at_period_end == true
      refute is_nil(updated.canceled_at)
    end
    
    test "queries subscriptions by stripe_subscription_id", %{customer: customer, plan: plan} do
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_find",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      found = Subscription
        |> Ash.Query.filter(stripe_subscription_id == "sub_find")
        |> Ash.read_one!()
        
      assert found.id == subscription.id
    end
    
    test "enforces unique stripe_subscription_id", %{customer: customer, plan: plan} do
      attrs = %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_unique",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      }
      
      assert {:ok, _subscription1} = Ash.create(Subscription, attrs)
      assert {:error, _} = Ash.create(Subscription, attrs)
    end
  end
end