defmodule SertantaiWeb.StripeWebhookController do
  use SertantaiWeb, :controller
  
  alias Sertantai.Accounts
  alias Sertantai.Accounts.User
  alias Sertantai.Billing
  alias Sertantai.Billing.{Customer, Subscription, Payment, Plan}
  
  require Logger
  require Ash.Query
  import Ash.Expr
  
  # Stripe webhook endpoint
  def webhook(conn, _params) do
    with {:ok, body, _conn} = Plug.Conn.read_body(conn),
         {:ok, event} <- verify_webhook_signature(conn, body),
         :ok <- handle_stripe_event(event) do
      send_resp(conn, 200, "OK")
    else
      {:error, reason} ->
        Logger.error("Stripe webhook error: #{inspect(reason)}")
        send_resp(conn, 400, "Bad Request")
    end
  end
  
  # Verify webhook signature to ensure it's from Stripe
  defp verify_webhook_signature(conn, body) do
    signature = get_req_header(conn, "stripe-signature") |> List.first()
    
    endpoint_secret = Application.get_env(:sertantai, :stripe_webhook_secret)
    
    case Stripe.Webhook.construct_event(body, signature, endpoint_secret) do
      {:ok, event} -> {:ok, event}
      {:error, reason} -> {:error, reason}
    end
  end
  
  # Handle different Stripe event types
  defp handle_stripe_event(%{"type" => event_type, "data" => %{"object" => object}}) do
    case event_type do
      # Subscription events
      "customer.subscription.created" ->
        handle_subscription_created(object)
        
      "customer.subscription.updated" ->
        handle_subscription_updated(object)
        
      "customer.subscription.deleted" ->
        handle_subscription_deleted(object)
        
      # Payment events
      "payment_intent.succeeded" ->
        handle_payment_succeeded(object)
        
      "payment_intent.payment_failed" ->
        handle_payment_failed(object)
        
      # Invoice events  
      "invoice.payment_succeeded" ->
        handle_invoice_payment_succeeded(object)
        
      "invoice.payment_failed" ->
        handle_invoice_payment_failed(object)
        
      # Customer events
      "customer.created" ->
        handle_customer_created(object)
        
      "customer.updated" ->
        handle_customer_updated(object)
        
      _ ->
        Logger.info("Unhandled Stripe event type: #{event_type}")
        :ok
    end
  end
  
  # Handle subscription created - create local record and upgrade user role
  defp handle_subscription_created(stripe_subscription) do
    with {:ok, customer} <- get_or_create_customer(stripe_subscription["customer"]),
         {:ok, plan} <- get_plan_by_stripe_price_id(stripe_subscription["items"]["data"] |> List.first() |> Map.get("price", %{}) |> Map.get("id")),
         {:ok, subscription} <- create_subscription(customer, plan, stripe_subscription),
         {:ok, _user} <- upgrade_user_role(customer.user_id, plan.user_role) do
      Logger.info("Subscription created and user role upgraded: #{inspect(subscription.id)}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to handle subscription created: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Handle subscription updated - update local record and adjust user role if needed
  defp handle_subscription_updated(stripe_subscription) do
    with {:ok, subscription} <- get_subscription_by_stripe_id(stripe_subscription["id"]),
         {:ok, updated_subscription} <- update_subscription_status(subscription, stripe_subscription),
         :ok <- handle_role_change_for_subscription_update(updated_subscription, stripe_subscription) do
      Logger.info("Subscription updated: #{inspect(updated_subscription.id)}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to handle subscription updated: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Handle subscription deleted - downgrade user role
  defp handle_subscription_deleted(stripe_subscription) do
    with {:ok, subscription} <- get_subscription_by_stripe_id(stripe_subscription["id"]),
         {:ok, _updated_subscription} <- cancel_subscription(subscription),
         {:ok, _user} <- downgrade_user_role(subscription.customer.user_id) do
      Logger.info("Subscription cancelled and user role downgraded: #{inspect(subscription.id)}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to handle subscription deleted: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Handle successful payment
  defp handle_payment_succeeded(payment_intent) do
    with {:ok, payment} <- create_or_update_payment(payment_intent, "succeeded") do
      Logger.info("Payment succeeded: #{inspect(payment.id)}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to handle payment succeeded: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Handle failed payment
  defp handle_payment_failed(payment_intent) do
    with {:ok, payment} <- create_or_update_payment(payment_intent, "failed") do
      Logger.info("Payment failed: #{inspect(payment.id)}")
      # TODO: Send notification to user about failed payment
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to handle payment failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Handle invoice payment succeeded
  defp handle_invoice_payment_succeeded(invoice) do
    Logger.info("Invoice payment succeeded: #{invoice["id"]}")
    # Most subscription logic is handled by subscription events
    :ok
  end
  
  # Handle invoice payment failed  
  defp handle_invoice_payment_failed(invoice) do
    Logger.info("Invoice payment failed: #{invoice["id"]}")
    # TODO: Send notification about failed invoice payment
    :ok
  end
  
  # Handle customer created
  defp handle_customer_created(stripe_customer) do
    Logger.info("Stripe customer created: #{stripe_customer["id"]}")
    # Customer creation is handled when subscription is created
    :ok
  end
  
  # Handle customer updated
  defp handle_customer_updated(stripe_customer) do
    with {:ok, customer} <- get_customer_by_stripe_id(stripe_customer["id"]),
         {:ok, _updated_customer} <- update_customer_info(customer, stripe_customer) do
      Logger.info("Customer updated: #{inspect(customer.id)}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to update customer: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Helper functions
  
  defp get_or_create_customer(stripe_customer_id) when is_binary(stripe_customer_id) do
    case get_customer_by_stripe_id(stripe_customer_id) do
      {:ok, customer} -> 
        {:ok, customer}
      {:error, _} ->
        # Fetch customer from Stripe and create local record
        with {:ok, stripe_customer} <- Stripe.Customer.retrieve(stripe_customer_id),
             {:ok, user} <- find_user_by_email(stripe_customer["email"]),
             {:ok, customer} <- create_customer(user, stripe_customer) do
          {:ok, customer}
        end
    end
  end
  
  defp get_customer_by_stripe_id(stripe_customer_id) do
    customer = Customer
      |> Ash.Query.filter(stripe_customer_id == ^stripe_customer_id)
      |> Ash.read_one!(actor: %{admin: true})
      
    case customer do
      nil -> {:error, :not_found}
      customer -> {:ok, customer}
    end
  end
  
  defp get_subscription_by_stripe_id(stripe_subscription_id) do
    subscription = Subscription
      |> Ash.Query.filter(stripe_subscription_id == ^stripe_subscription_id)
      |> Ash.Query.load([:customer, :plan])
      |> Ash.read_one!(actor: %{admin: true})
      
    case subscription do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription}
    end
  end
  
  defp get_plan_by_stripe_price_id(stripe_price_id) do
    plan = Plan
      |> Ash.Query.filter(stripe_price_id == ^stripe_price_id)
      |> Ash.read_one!(actor: %{admin: true})
      
    case plan do
      nil -> {:error, :plan_not_found}
      plan -> {:ok, plan}
    end
  end
  
  defp find_user_by_email(email) do
    user = User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(actor: %{admin: true})
      
    case user do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end
  
  defp create_customer(user, stripe_customer) do
    params = %{
      user_id: user.id,
      stripe_customer_id: stripe_customer["id"],
      email: stripe_customer["email"],
      name: stripe_customer["name"],
      phone: stripe_customer["phone"],
      address: stripe_customer["address"]
    }
    
    case Ash.create(Customer, params, actor: %{admin: true}) do
      {:ok, customer} -> {:ok, customer}
      {:error, error} -> {:error, error}
    end
  end
  
  defp create_subscription(customer, plan, stripe_subscription) do
    params = %{
      customer_id: customer.id,
      plan_id: plan.id,
      stripe_subscription_id: stripe_subscription["id"],
      status: stripe_subscription["status"],
      current_period_start: DateTime.from_unix!(stripe_subscription["current_period_start"]),
      current_period_end: DateTime.from_unix!(stripe_subscription["current_period_end"]),
      cancel_at_period_end: stripe_subscription["cancel_at_period_end"] || false,
      canceled_at: if(stripe_subscription["canceled_at"], do: DateTime.from_unix!(stripe_subscription["canceled_at"]))
    }
    
    case Ash.create(Subscription, params, actor: %{admin: true}) do
      {:ok, subscription} -> {:ok, subscription}
      {:error, error} -> {:error, error}
    end
  end
  
  defp update_subscription_status(subscription, stripe_subscription) do
    params = %{
      status: stripe_subscription["status"],
      current_period_start: DateTime.from_unix!(stripe_subscription["current_period_start"]),
      current_period_end: DateTime.from_unix!(stripe_subscription["current_period_end"]),
      cancel_at_period_end: stripe_subscription["cancel_at_period_end"] || false,
      canceled_at: if(stripe_subscription["canceled_at"], do: DateTime.from_unix!(stripe_subscription["canceled_at"]))
    }
    
    case Ash.update(subscription, params, actor: %{admin: true}) do
      {:ok, subscription} -> {:ok, subscription}
      {:error, error} -> {:error, error}
    end
  end
  
  defp cancel_subscription(subscription) do
    params = %{
      status: "canceled",
      canceled_at: DateTime.utc_now()
    }
    
    case Ash.update(subscription, params, actor: %{admin: true}) do
      {:ok, subscription} -> {:ok, subscription}
      {:error, error} -> {:error, error}
    end
  end
  
  defp create_or_update_payment(payment_intent, status) do
    # Check if payment already exists
    existing_payment = Payment
      |> Ash.Query.filter(stripe_payment_intent_id == ^payment_intent["id"])
      |> Ash.read_one!(actor: %{admin: true})
      
    customer = case get_customer_by_stripe_id(payment_intent["customer"]) do
      {:ok, customer} -> customer
      _ -> nil
    end
    
    params = %{
      amount: payment_intent["amount"] / 100.0, # Convert from cents
      currency: payment_intent["currency"],
      status: status,
      stripe_payment_intent_id: payment_intent["id"],
      payment_method: payment_intent["payment_method_types"] |> List.first(),
      description: payment_intent["description"],
      processed_at: DateTime.utc_now()
    }
    
    params = if customer, do: Map.put(params, :customer_id, customer.id), else: params
    
    case existing_payment do
      nil ->
        Ash.create(Payment, params, actor: %{admin: true})
      payment ->
        Ash.update(payment, params, actor: %{admin: true})
    end
  end
  
  defp update_customer_info(customer, stripe_customer) do
    params = %{
      email: stripe_customer["email"],
      name: stripe_customer["name"],
      phone: stripe_customer["phone"],
      address: stripe_customer["address"]
    }
    
    Ash.update(customer, params, actor: %{admin: true})
  end
  
  # Role management functions
  
  defp upgrade_user_role(user_id, target_role) when target_role in [:professional, :admin] do
    user = Ash.get!(User, user_id, actor: %{admin: true})
    
    # Only upgrade if current role is lower
    if should_upgrade_role?(user.role, target_role) do
      case Ash.update(user, %{role: target_role}, actor: %{admin: true}) do
        {:ok, user} ->
          Logger.info("Upgraded user #{user.id} role from #{user.role} to #{target_role}")
          create_role_audit_entry(user.id, user.role, target_role, "subscription_created")
          {:ok, user}
        {:error, error} ->
          {:error, error}
      end
    else
      {:ok, user}
    end
  end
  
  defp downgrade_user_role(user_id) do
    user = Ash.get!(User, user_id, actor: %{admin: true})
    
    # Check if user has any other active subscriptions
    active_subscriptions = Subscription
      |> Ash.Query.filter(customer.user_id == ^user_id)
      |> Ash.Query.filter(status == "active")
      |> Ash.read!(actor: %{admin: true})
      
    if Enum.empty?(active_subscriptions) do
      # Downgrade to member role if no active subscriptions
      case Ash.update(user, %{role: :member}, actor: %{admin: true}) do
        {:ok, user} ->
          Logger.info("Downgraded user #{user.id} role from #{user.role} to member")
          create_role_audit_entry(user.id, user.role, :member, "subscription_canceled")
          {:ok, user}
        {:error, error} ->
          {:error, error}
      end
    else
      {:ok, user}
    end
  end
  
  defp handle_role_change_for_subscription_update(subscription, stripe_subscription) do
    # Handle role changes based on subscription status changes
    case stripe_subscription["status"] do
      "active" ->
        # Ensure user has appropriate role
        upgrade_user_role(subscription.customer.user_id, subscription.plan.user_role)
        :ok
        
      status when status in ["canceled", "incomplete_expired", "unpaid"] ->
        # Check if should downgrade
        downgrade_user_role(subscription.customer.user_id)
        :ok
        
      _ ->
        :ok
    end
  end
  
  defp should_upgrade_role?(current_role, target_role) do
    role_hierarchy = %{
      member: 1,
      professional: 2,
      admin: 3
    }
    
    Map.get(role_hierarchy, current_role, 0) < Map.get(role_hierarchy, target_role, 0)
  end
  
  defp create_role_audit_entry(user_id, from_role, to_role, reason) do
    # TODO: Implement audit trail for role changes
    Logger.info("Role change audit: User #{user_id} from #{from_role} to #{to_role} - Reason: #{reason}")
  end
end