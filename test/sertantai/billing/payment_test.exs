defmodule Sertantai.Billing.PaymentTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription, Payment}
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
      email: "payment@example.com",
      password: "test123",
      password_confirmation: "test123",
      role: :member
    }, action: :register_with_password, actor: admin_user)
    
    # Create test plan
    {:ok, plan} = Ash.create(Plan, %{
      name: "Payment Plan",
      stripe_price_id: "price_payment",
      amount: 29.99,
      currency: "usd",
      interval: "month",
      user_role: "professional"
    }, actor: admin_user)
    
    # Create test customer
    {:ok, customer} = Ash.create(Customer, %{
      user_id: user.id,
      stripe_customer_id: "cus_payment",
      email: user.email
    }, actor: admin_user)
    
    # Create test subscription
    {:ok, subscription} = Ash.create(Subscription, %{
      customer_id: customer.id,
      plan_id: plan.id,
      stripe_subscription_id: "sub_payment",
      status: "active",
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
    }, actor: admin_user)
    
    {:ok, admin_user: admin_user, user: user, plan: plan, customer: customer, subscription: subscription}
  end
  
  describe "Payment resource" do
    test "creates a successful payment", %{admin_user: admin_user, customer: customer, subscription: subscription} do
      attrs = %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_test123",
        payment_method: "card",
        description: "Monthly subscription payment",
        processed_at: DateTime.utc_now()
      }
      
      assert {:ok, payment} = Ash.create(Payment, attrs, actor: admin_user)
      assert payment.customer_id == customer.id
      assert payment.subscription_id == subscription.id
      assert Decimal.equal?(payment.amount, Decimal.new("29.99"))
      assert payment.currency == "usd"
      assert payment.status == :succeeded
      assert payment.stripe_payment_intent_id == "pi_test123"
      assert payment.payment_method == "card"
      assert payment.description == "Monthly subscription payment"
    end
    
    test "creates a failed payment", %{admin_user: admin_user, customer: customer} do
      attrs = %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_failed123",
        payment_method: "card",
        description: "Failed payment attempt",
        failure_reason: "insufficient_funds",
        processed_at: DateTime.utc_now()
      }
      
      assert {:ok, payment} = Ash.create(Payment, attrs, actor: admin_user)
      assert payment.status == :failed
      assert payment.failure_reason == "insufficient_funds"
    end
    
    test "loads customer and subscription relationships", %{admin_user: admin_user, customer: customer, subscription: subscription} do
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_rel",
        processed_at: DateTime.utc_now()
      }, actor: admin_user)
      
      loaded_payment = Ash.load!(payment, [:customer, :subscription], actor: admin_user)
      assert loaded_payment.customer.id == customer.id
      assert loaded_payment.subscription.id == subscription.id
    end
    
    test "queries payments by status", %{admin_user: admin_user, customer: customer} do
      # Create successful payment
      {:ok, success_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_success",
        processed_at: DateTime.utc_now()
      }, actor: admin_user)
      
      # Create failed payment
      {:ok, failed_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_fail",
        processed_at: DateTime.utc_now()
      }, actor: admin_user)
      
      successful_payments = Payment
        |> Ash.Query.filter(status == :succeeded)
        |> Ash.read!(actor: admin_user)
        
      assert Enum.any?(successful_payments, &(&1.id == success_payment.id))
      refute Enum.any?(successful_payments, &(&1.id == failed_payment.id))
    end
    
    test "queries payments by stripe_payment_intent_id", %{admin_user: admin_user, customer: customer} do
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_unique",
        processed_at: DateTime.utc_now()
      }, actor: admin_user)
      
      found = Payment
        |> Ash.Query.filter(stripe_payment_intent_id == "pi_unique")
        |> Ash.read_one!(actor: admin_user)
        
      assert found.id == payment.id
    end
    
    test "sorts payments by processed_at", %{admin_user: admin_user, customer: customer} do
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -3600, :second)
      
      {:ok, _old_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 19.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_old",
        processed_at: earlier
      }, actor: admin_user)
      
      {:ok, new_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_new",
        processed_at: now
      }, actor: admin_user)
      
      payments = Payment
        |> Ash.Query.sort(processed_at: :desc)
        |> Ash.read!(actor: admin_user)
        
      assert List.first(payments).id == new_payment.id
    end
    
    test "updates payment status from pending to succeeded", %{admin_user: admin_user, customer: customer} do
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "pending",
        stripe_payment_intent_id: "pi_pending",
        processed_at: DateTime.utc_now()
      }, actor: admin_user)
      
      assert {:ok, updated} = Ash.update(payment, %{
        status: "succeeded",
        processed_at: DateTime.utc_now()
      }, actor: admin_user)
      
      assert updated.status == :succeeded
    end
  end
end