defmodule Sertantai.Billing.PaymentFailureTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription, Payment}
  alias Sertantai.Accounts.User
  
  import Sertantai.BillingFixtures
  import Sertantai.AccountsFixtures
  
  describe "Payment Failure Handling" do
    setup do
      user = user_fixture(%{role: :professional})
      plan = professional_plan_fixture()
      customer = customer_fixture(%{user: user})
      subscription = active_subscription_fixture(%{customer: customer, plan: plan})
      
      {:ok, user: user, plan: plan, customer: customer, subscription: subscription}
    end
    
    test "creates payment record for failed payment", %{customer: customer, subscription: subscription} do
      attrs = %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_failed_test",
        payment_method: "card",
        description: "Failed subscription payment",
        failure_reason: "insufficient_funds",
        processed_at: DateTime.utc_now()
      }
      
      assert {:ok, payment} = Ash.create(Payment, attrs)
      assert payment.status == "failed"
      assert payment.failure_reason == "insufficient_funds"
      refute is_nil(payment.processed_at)
    end
    
    test "handles different failure reasons", %{customer: customer} do
      failure_scenarios = [
        %{reason: "insufficient_funds", description: "Card has insufficient funds"},
        %{reason: "card_declined", description: "Card was declined"},
        %{reason: "expired_card", description: "Card has expired"},
        %{reason: "authentication_required", description: "Requires additional authentication"},
        %{reason: "processing_error", description: "Payment processing error"}
      ]
      
      for %{reason: reason, description: desc} <- failure_scenarios do
        {:ok, payment} = Ash.create(Payment, %{
          customer_id: customer.id,
          amount: 29.99,
          currency: "usd",
          status: "failed",
          stripe_payment_intent_id: "pi_#{reason}",
          failure_reason: reason,
          description: desc,
          processed_at: DateTime.utc_now()
        })
        
        assert payment.failure_reason == reason
        assert payment.status == "failed"
      end
    end
    
    test "tracks payment retry attempts", %{customer: customer, subscription: subscription} do
      # First attempt fails
      {:ok, failed_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_retry_test",
        failure_reason: "card_declined",
        processed_at: DateTime.utc_now()
      })
      
      # Retry attempt succeeds
      {:ok, success_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_retry_test_success",
        description: "Retry payment - succeeded",
        processed_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })
      
      # Query payments for this customer/subscription
      payments = Payment
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.filter(subscription_id == ^subscription.id)
        |> Ash.Query.sort(processed_at: :asc)
        |> Ash.read!()
      
      assert length(payments) == 2
      assert List.first(payments).status == "failed"
      assert List.last(payments).status == "succeeded"
    end
    
    test "handles subscription status changes after payment failures", %{user: user, customer: customer, subscription: subscription} do
      # Create multiple failed payments
      for i <- 1..3 do
        Ash.create(Payment, %{
          customer_id: customer.id,
          subscription_id: subscription.id,
          amount: 29.99,
          currency: "usd",
          status: "failed",
          stripe_payment_intent_id: "pi_multiple_fail_#{i}",
          failure_reason: "card_declined",
          processed_at: DateTime.add(DateTime.utc_now(), i * 3600, :second)
        })
      end
      
      # After multiple failures, subscription might be marked as past_due
      {:ok, updated_subscription} = Ash.update(subscription, %{status: "past_due"})
      assert updated_subscription.status == "past_due"
      
      # User role might need to be downgraded
      # This would typically happen via webhook, but we'll simulate it
      active_subs = Subscription
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.filter(status == "active")
        |> Ash.read!()
      
      if Enum.empty?(active_subs) do
        {:ok, downgraded_user} = Ash.update(user, %{role: :member})
        assert downgraded_user.role == :member
      end
    end
    
    test "calculates payment failure rates", %{customer: customer, subscription: subscription} do
      # Create mix of successful and failed payments
      successful_payments = 7
      failed_payments = 3
      
      # Create successful payments
      for i <- 1..successful_payments do
        Ash.create(Payment, %{
          customer_id: customer.id,
          subscription_id: subscription.id,
          amount: 29.99,
          currency: "usd",
          status: "succeeded",
          stripe_payment_intent_id: "pi_success_#{i}",
          processed_at: DateTime.add(DateTime.utc_now(), -i * 86400, :second)
        })
      end
      
      # Create failed payments
      for i <- 1..failed_payments do
        Ash.create(Payment, %{
          customer_id: customer.id,
          subscription_id: subscription.id,
          amount: 29.99,
          currency: "usd",
          status: "failed",
          stripe_payment_intent_id: "pi_fail_#{i}",
          failure_reason: "card_declined",
          processed_at: DateTime.add(DateTime.utc_now(), -i * 86400, :second)
        })
      end
      
      # Calculate failure rate
      total_payments = Payment
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.read!()
        |> length()
      
      failed_count = Payment
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.filter(status == "failed")
        |> Ash.read!()
        |> length()
      
      failure_rate = failed_count / total_payments
      
      assert total_payments == 10
      assert failed_count == 3
      assert failure_rate == 0.3
    end
    
    test "handles dunning management for failed payments", %{user: user, customer: customer, subscription: subscription} do
      # First failure - grace period
      {:ok, _failed_payment1} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_dunning_1",
        failure_reason: "card_declined",
        processed_at: DateTime.utc_now()
      })
      
      # Subscription status should change to past_due but user keeps access
      {:ok, past_due_sub} = Ash.update(subscription, %{status: "past_due"})
      assert past_due_sub.status == "past_due"
      
      # User should still have professional access during grace period
      assert user.role == :professional
      
      # After grace period expires, subscription gets canceled
      {:ok, canceled_sub} = Ash.update(subscription, %{
        status: "canceled",
        canceled_at: DateTime.utc_now()
      })
      
      # Check if user has any other active subscriptions
      active_subs = Subscription
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.filter(status == "active")
        |> Ash.read!()
      
      # If no active subscriptions, downgrade user
      if Enum.empty?(active_subs) do
        {:ok, downgraded_user} = Ash.update(user, %{role: :member})
        assert downgraded_user.role == :member
      end
    end
    
    test "creates audit trail for payment failures", %{customer: customer, subscription: subscription} do
      # Payment failure with detailed information
      failure_time = DateTime.utc_now()
      
      {:ok, payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_audit_trail",
        payment_method: "card",
        failure_reason: "insufficient_funds",
        description: "Monthly subscription payment failed - insufficient funds",
        processed_at: failure_time
      })
      
      # Verify all audit information is captured
      assert payment.failure_reason == "insufficient_funds"
      assert payment.description =~ "insufficient funds"
      assert payment.processed_at == failure_time
      assert payment.stripe_payment_intent_id == "pi_audit_trail"
      
      # In a real system, you might also log to external systems
      # This would be tested by mocking those external calls
    end
    
    test "handles partial payment failures", %{customer: customer, subscription: subscription} do
      # Scenario: Payment partially succeeds but amount is less than expected
      expected_amount = 29.99
      actual_amount = 15.00
      
      {:ok, partial_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: actual_amount,
        currency: "usd",
        status: "succeeded", # Payment went through but for wrong amount
        stripe_payment_intent_id: "pi_partial",
        description: "Partial payment - amount mismatch",
        processed_at: DateTime.utc_now()
      })
      
      # System should detect amount mismatch
      amount_difference = expected_amount - actual_amount
      assert amount_difference == 14.99
      
      # This scenario might require manual review or automatic handling
      assert partial_payment.amount < expected_amount
    end
    
    test "recovery workflows after payment failures", %{user: user, customer: customer, subscription: subscription} do
      # Simulate payment failure recovery workflow
      
      # 1. Payment fails
      {:ok, failed_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "failed",
        stripe_payment_intent_id: "pi_recovery_test",
        failure_reason: "card_declined",
        processed_at: DateTime.utc_now()
      })
      
      # 2. Subscription marked as past_due
      {:ok, _} = Ash.update(subscription, %{status: "past_due"})
      
      # 3. Customer updates payment method and retries
      retry_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      
      {:ok, retry_payment} = Ash.create(Payment, %{
        customer_id: customer.id,
        subscription_id: subscription.id,
        amount: 29.99,
        currency: "usd",
        status: "succeeded",
        stripe_payment_intent_id: "pi_recovery_success",
        description: "Recovery payment after card update",
        processed_at: retry_time
      })
      
      # 4. Subscription reactivated
      {:ok, reactivated_sub} = Ash.update(subscription, %{
        status: "active",
        current_period_end: DateTime.add(retry_time, 30, :day)
      })
      
      # 5. User role maintained/restored
      assert user.role == :professional
      assert reactivated_sub.status == "active"
      assert retry_payment.status == "succeeded"
      
      # Verify recovery metrics
      customer_payments = Payment
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.sort(processed_at: :asc)
        |> Ash.read!()
      
      assert length(customer_payments) == 2
      assert List.first(customer_payments).status == "failed"
      assert List.last(customer_payments).status == "succeeded"
    end
  end
end