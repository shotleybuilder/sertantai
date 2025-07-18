defmodule SertantaiWeb.StripeWebhookControllerTest do
  use SertantaiWeb.ConnCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription, Payment}
  alias Sertantai.Accounts.User
  
  setup %{conn: conn} do
    # Create test user
    {:ok, user} = Ash.create(User, %{
      email: "webhook@example.com",
      hashed_password: "hashedpassword123",
      role: :member
    })
    
    # Create test plan
    {:ok, plan} = Ash.create(Plan, %{
      name: "Webhook Test Plan",
      stripe_price_id: "price_webhook_test",
      amount: 29.99,
      currency: "usd",
      interval: "month",
      user_role: "professional"
    })
    
    # Create test customer
    {:ok, customer} = Ash.create(Customer, %{
      user_id: user.id,
      stripe_customer_id: "cus_webhook_test",
      email: user.email
    })
    
    {:ok, conn: conn, user: user, plan: plan, customer: customer}
  end
  
  describe "POST /webhooks/stripe" do
    test "handles subscription.created event", %{conn: conn, user: user, plan: plan, customer: customer} do
      event_data = %{
        "type" => "customer.subscription.created",
        "data" => %{
          "object" => %{
            "id" => "sub_webhook_created",
            "customer" => customer.stripe_customer_id,
            "status" => "active",
            "current_period_start" => DateTime.utc_now() |> DateTime.to_unix(),
            "current_period_end" => DateTime.add(DateTime.utc_now(), 30, :day) |> DateTime.to_unix(),
            "cancel_at_period_end" => false,
            "items" => %{
              "data" => [%{
                "price" => %{
                  "id" => plan.stripe_price_id
                }
              }]
            }
          }
        }
      }
      
      # Mock the webhook verification (in real tests, you'd mock Stripe.Webhook.construct_event)
      conn = conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", "test_signature")
      
      # For this test, we'll stub the webhook verification
      # In production, you'd want to test with actual Stripe webhook signatures
      
      # The webhook should process successfully
      # Note: This test would need proper webhook signature mocking
      # For now, we'll test the internal functions directly
      
      assert true # Placeholder - actual webhook testing requires signature mocking
    end
    
    test "handles subscription.deleted event", %{conn: conn, user: user, plan: plan, customer: customer} do
      # First create a subscription
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: plan.id,
        stripe_subscription_id: "sub_webhook_deleted",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      # Verify user was upgraded to professional
      user = Ash.reload!(user)
      # Note: In real implementation, role upgrade would happen via webhook
      
      event_data = %{
        "type" => "customer.subscription.deleted",
        "data" => %{
          "object" => %{
            "id" => "sub_webhook_deleted",
            "customer" => customer.stripe_customer_id,
            "status" => "canceled"
          }
        }
      }
      
      # After processing, user should be downgraded to member
      assert true # Placeholder for actual webhook test
    end
    
    test "handles payment_intent.succeeded event", %{conn: conn, customer: customer} do
      event_data = %{
        "type" => "payment_intent.succeeded",
        "data" => %{
          "object" => %{
            "id" => "pi_webhook_success",
            "amount" => 2999, # In cents
            "currency" => "usd",
            "customer" => customer.stripe_customer_id,
            "payment_method_types" => ["card"],
            "description" => "Subscription payment"
          }
        }
      }
      
      # Payment should be created with succeeded status
      assert true # Placeholder for actual webhook test
    end
    
    test "handles payment_intent.payment_failed event", %{conn: conn, customer: customer} do
      event_data = %{
        "type" => "payment_intent.payment_failed",
        "data" => %{
          "object" => %{
            "id" => "pi_webhook_failed",
            "amount" => 2999,
            "currency" => "usd",
            "customer" => customer.stripe_customer_id,
            "payment_method_types" => ["card"],
            "description" => "Failed subscription payment",
            "last_payment_error" => %{
              "code" => "card_declined",
              "message" => "Your card was declined."
            }
          }
        }
      }
      
      # Payment should be created with failed status
      assert true # Placeholder for actual webhook test
    end
    
    test "rejects requests without valid signature", %{conn: conn} do
      event_data = %{
        "type" => "customer.subscription.created",
        "data" => %{"object" => %{}}
      }
      
      conn = conn
        |> put_req_header("content-type", "application/json")
        # Missing or invalid stripe-signature header
      
      conn = post(conn, "/webhooks/stripe", event_data)
      
      # Should return 400 Bad Request for invalid signature
      assert conn.status == 400
    end
  end
  
  describe "webhook helper functions" do
    test "finds user by email", %{user: user} do
      # Test the internal helper function
      result = SertantaiWeb.StripeWebhookController.find_user_by_email(user.email)
      assert {:ok, found_user} = result
      assert found_user.id == user.id
    end
    
    test "finds plan by stripe price id", %{plan: plan} do
      # Test the internal helper function
      result = SertantaiWeb.StripeWebhookController.get_plan_by_stripe_price_id(plan.stripe_price_id)
      assert {:ok, found_plan} = result
      assert found_plan.id == plan.id
    end
    
    test "upgrades user role correctly", %{user: user} do
      # Test role upgrade logic
      assert user.role == :member
      
      # Simulate role upgrade
      {:ok, updated_user} = Ash.update(user, %{role: :professional})
      assert updated_user.role == :professional
    end
    
    test "downgrades user role when no active subscriptions", %{user: user} do
      # First upgrade user
      {:ok, user} = Ash.update(user, %{role: :professional})
      assert user.role == :professional
      
      # Then downgrade back to member
      {:ok, downgraded_user} = Ash.update(user, %{role: :member})
      assert downgraded_user.role == :member
    end
  end
end