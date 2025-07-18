defmodule Sertantai.Billing.SubscriptionTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription}
  alias Sertantai.Accounts.User
  
  require Ash.Query
  import Ash.Expr
  
  setup do
    # Create test admin user to use as actor
    {:ok, admin_user} = Ash.create(User, %{
      email: "admin@test.local",
      password: "test123",
      password_confirmation: "test123",
      role: :admin
    }, action: :register_with_password)
    
    # Create test user
    {:ok, user} = Ash.create(User, %{
      email: "sub@example.com",
      password: "test123",
      password_confirmation: "test123",
      role: :member
    }, action: :register_with_password, actor: admin_user)
    
    # Create test plan
    {:ok, plan} = Ash.create(Plan, %{
      name: "Test Plan",
      stripe_price_id: "price_test",
      amount: 29.99,
      currency: "usd",
      interval: "month",
      user_role: "professional"
    }, actor: admin_user)
    
    # Create test customer
    {:ok, customer} = Ash.create(Customer, %{
      user_id: user.id,
      stripe_customer_id: "cus_sub_test",
      email: user.email
    }, actor: admin_user)
    
    {:ok, admin_user: admin_user, user: user, plan: plan, customer: customer}
  end
  
  describe "Subscription resource" do
    test "creates a subscription", %{admin_user: admin_user, customer: customer, plan: plan} do
      attrs = %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_test123",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
        cancel_at_period_end: false
      }
      
      assert {:ok, subscription} = Ash.create(Subscription, attrs, actor: admin_user)
      assert subscription.customer_id == customer.id
      assert subscription.plan_id == plan.id
      assert subscription.stripe_subscription_id == "sub_test123"
      assert subscription.status == :active
      assert subscription.cancel_at_period_end == false
    end
    
    test "loads customer and plan relationships", %{admin_user: admin_user, customer: customer, plan: plan} do
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_rel",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      }, actor: admin_user)
      
      loaded_subscription = Ash.load!(subscription, [:customer, :plan], actor: admin_user)
      assert loaded_subscription.customer.id == customer.id
      assert loaded_subscription.plan.id == plan.id
      assert loaded_subscription.plan.name == "Test Plan"
    end
    
    test "queries active subscriptions", %{admin_user: admin_user, customer: customer, plan: plan} do
      # Create active subscription
      {:ok, active_sub} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_active",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      }, actor: admin_user)
      
      # Create canceled subscription
      {:ok, canceled_sub} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_canceled",
        status: "canceled",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
        canceled_at: DateTime.utc_now()
      }, actor: admin_user)
      
      active_subscriptions = Subscription
        |> Ash.Query.filter(status == :active)
        |> Ash.read!(actor: admin_user)
        
      assert Enum.any?(active_subscriptions, &(&1.id == active_sub.id))
      refute Enum.any?(active_subscriptions, &(&1.id == canceled_sub.id))
    end
    
    test "updates subscription status", %{admin_user: admin_user, customer: customer, plan: plan} do
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_update",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      }, actor: admin_user)
      
      assert {:ok, updated} = Ash.update(subscription, %{
        status: "canceled",
        cancel_at_period_end: true,
        canceled_at: DateTime.utc_now()
      }, actor: admin_user)
      
      assert updated.status == :canceled
      assert updated.cancel_at_period_end == true
      refute is_nil(updated.canceled_at)
    end
    
    test "queries subscriptions by stripe_subscription_id", %{admin_user: admin_user, customer: customer, plan: plan} do
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_find",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      }, actor: admin_user)
      
      found = Subscription
        |> Ash.Query.filter(stripe_subscription_id == "sub_find")
        |> Ash.read_one!(actor: admin_user)
        
      assert found.id == subscription.id
    end
    
    test "enforces unique stripe_subscription_id", %{admin_user: admin_user, customer: customer, plan: plan} do
      attrs = %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_unique",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      }
      
      assert {:ok, _subscription1} = Ash.create(Subscription, attrs, actor: admin_user)
      assert {:error, _} = Ash.create(Subscription, attrs, actor: admin_user)
    end
  end
end