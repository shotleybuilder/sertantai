defmodule Sertantai.Billing.PaymentTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription, Payment}
  alias Sertantai.Accounts.User
  
  setup do
    # Create test user
    {:ok, user} = Ash.create(User, %{
      email: "payment@example.com",
      hashed_password: "hashedpassword123",
      role: :member
    })
    
    # Create test plan
    {:ok, plan} = Ash.create(Plan, %{
      name: "Payment Plan",
      stripe_price_id: "price_payment",
      amount: 29.99,
      currency: "usd",
      interval: "month",
      user_role: "professional"
    })
    
    # Create test customer
    {:ok, customer} = Ash.create(Customer, %{
      user_id: user.id,
      stripe_customer_id: "cus_payment",
      email: user.email
    })
    
    # Create test subscription
    {:ok, subscription} = Ash.create(Subscription, %{
      customer_id: customer.id,
      plan_id: plan.id,
      stripe_subscription_id: "sub_payment",
      status: "active",
      current_period_start: DateTime.utc_now(),
      current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
    })
    
    {:ok, user: user, plan: plan, customer: customer, subscription: subscription}
  end
  
  describe "Payment resource" do
    test "creates a successful payment", %{customer: customer, subscription: subscription} do
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
      
      assert {:ok, payment} = Ash.create(Payment, attrs)
      assert payment.customer_id == customer.id
      assert payment.subscription_id == subscription.id
      assert payment.amount == 29.99
      assert payment.currency == "usd"
      assert payment.status == "succeeded"
      assert payment.stripe_payment_intent_id == "pi_test123"
      assert payment.payment_method == "card"
      assert payment.description == "Monthly subscription payment"
    end
    
    test "creates a failed payment", %{customer: customer} do
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
      
      assert {:ok, payment} = Ash.create(Payment, attrs)
      assert payment.status == "failed"
      assert payment.failure_reason == "insufficient_funds"
    end
    
    test "loads customer and subscription relationships", %{customer: customer, subscription: subscription} do
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_rel",
        processed_at: DateTime.utc_now()
      })
      
      loaded_payment = Ash.load!(payment, [:customer, :subscription])
      assert loaded_payment.customer.id == customer.id
      assert loaded_payment.subscription.id == subscription.id
    end
    
    test "queries payments by status", %{customer: customer} do
      # Create successful payment
      {:ok, success_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_success",
        processed_at: DateTime.utc_now()
      })
      
      # Create failed payment
      {:ok, failed_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_fail",
        processed_at: DateTime.utc_now()
      })
      
      successful_payments = Payment
        |> Ash.Query.filter(status == "succeeded")
        |> Ash.read!()
        
      assert Enum.any?(successful_payments, &(&1.id == success_payment.id))
      refute Enum.any?(successful_payments, &(&1.id == failed_payment.id))
    end
    
    test "queries payments by stripe_payment_intent_id", %{customer: customer} do
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_unique",
        processed_at: DateTime.utc_now()
      })
      
      found = Payment
        |> Ash.Query.filter(stripe_payment_intent_id == "pi_unique")
        |> Ash.read_one!()
        
      assert found.id == payment.id
    end
    
    test "sorts payments by processed_at", %{customer: customer} do
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -3600, :second)
      
      {:ok, old_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 19.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_old",
        processed_at: earlier
      })
      
      {:ok, new_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_new",
        processed_at: now
      })
      
      payments = Payment
        |> Ash.Query.sort(processed_at: :desc)
        |> Ash.read!()
        
      assert List.first(payments).id == new_payment.id
    end
    
    test "updates payment status from pending to succeeded", %{customer: customer} do
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        amount: 29.99,
        currency: "usd",
        status: "pending",
        stripe_payment_intent_id: "pi_pending",
        processed_at: DateTime.utc_now()
      })
      
      assert {:ok, updated} = Ash.update(payment, %{
        status: "succeeded",
        processed_at: DateTime.utc_now()
      })
      
      assert updated.status == "succeeded"
    end
  end
end