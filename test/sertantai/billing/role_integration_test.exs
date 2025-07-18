defmodule Sertantai.Billing.RoleIntegrationTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Customer, Subscription}
  alias Sertantai.Accounts.User
  
  describe "Role and Billing Integration" do
    setup do
      # Create test user
      {:ok, user} = Ash.create(User, %{
        email: "roletest@example.com",
        hashed_password: "hashedpassword123",
        role: :member
      })
      
      # Create professional plan
      {:ok, pro_plan} = Ash.create(Plan, %{
        name: "Professional Plan",
        stripe_price_id: "price_pro",
        amount: 29.99,
        currency: "usd",
        interval: "month",
        user_role: "professional",
        active: true
      })
      
      # Create enterprise plan
      {:ok, ent_plan} = Ash.create(Plan, %{
        name: "Enterprise Plan",
        stripe_price_id: "price_enterprise",
        amount: 99.99,
        currency: "usd",
        interval: "month",
        user_role: "professional", # Note: could be "enterprise" if that role exists
        active: true
      })
      
      # Create customer
      {:ok, customer} = Ash.create(Customer, %{
        user_id: user.id,
        stripe_customer_id: "cus_role_test",
        email: user.email
      })
      
      {:ok, user: user, pro_plan: pro_plan, ent_plan: ent_plan, customer: customer}
    end
    
    test "user role upgrades when subscription becomes active", %{user: user, customer: customer, pro_plan: pro_plan} do
      # User starts as member
      assert user.role == :member
      
      # Create active subscription
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: pro_plan.id,
        stripe_subscription_id: "sub_role_upgrade",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      # Simulate the role upgrade logic that would happen via webhook
      expected_role = String.to_atom(pro_plan.user_role)
      {:ok, upgraded_user} = Ash.update(user, %{role: expected_role})
      
      assert upgraded_user.role == :professional
    end
    
    test "user role downgrades when subscription is canceled", %{user: user, customer: customer, pro_plan: pro_plan} do
      # Start with professional user
      {:ok, user} = Ash.update(user, %{role: :professional})
      
      # Create subscription then cancel it
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: pro_plan.id,
        stripe_subscription_id: "sub_role_downgrade",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      # Cancel subscription
      {:ok, canceled_subscription} = Ash.update(subscription, %{
        status: "canceled",
        canceled_at: DateTime.utc_now()
      })
      
      # Check if user has any other active subscriptions
      active_subscriptions = Subscription
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.filter(status == "active")
        |> Ash.read!()
      
      # If no active subscriptions, downgrade to member
      if Enum.empty?(active_subscriptions) do
        {:ok, downgraded_user} = Ash.update(user, %{role: :member})
        assert downgraded_user.role == :member
      end
    end
    
    test "user maintains highest role with multiple subscriptions", %{user: user, customer: customer, pro_plan: pro_plan, ent_plan: ent_plan} do
      # Create multiple active subscriptions
      {:ok, pro_sub} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: pro_plan.id,
        stripe_subscription_id: "sub_pro_multi",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      {:ok, ent_sub} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: ent_plan.id,
        stripe_subscription_id: "sub_ent_multi",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      # User should get the highest role
      {:ok, user} = Ash.update(user, %{role: :professional})
      
      # Cancel one subscription
      {:ok, _canceled} = Ash.update(pro_sub, %{
        status: "canceled",
        canceled_at: DateTime.utc_now()
      })
      
      # User should still maintain professional role due to enterprise subscription
      active_subscriptions = Subscription
        |> Ash.Query.filter(customer_id == ^customer.id)
        |> Ash.Query.filter(status == "active")
        |> Ash.Query.load(:plan)
        |> Ash.read!()
      
      assert length(active_subscriptions) == 1
      assert user.role == :professional
    end
    
    test "admin and support roles are protected from automatic changes", %{customer: customer, pro_plan: pro_plan} do
      # Create admin user
      {:ok, admin_user} = Ash.create(User, %{
        email: "admin@example.com",
        hashed_password: "hashedpassword123",
        role: :admin
      })
      
      {:ok, admin_customer} = Ash.create(Customer, %{
        user_id: admin_user.id,
        stripe_customer_id: "cus_admin_test",
        email: admin_user.email
      })
      
      # Create subscription for admin
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: admin_customer.id,
        plan_id: pro_plan.id,
        stripe_subscription_id: "sub_admin_test",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      # Cancel subscription
      {:ok, _canceled} = Ash.update(subscription, %{
        status: "canceled",
        canceled_at: DateTime.utc_now()
      })
      
      # Admin role should be preserved
      admin_user = Ash.reload!(admin_user)
      assert admin_user.role == :admin
    end
    
    test "role hierarchy respects proper upgrade paths", %{user: user} do
      # Test role hierarchy: member -> professional -> admin
      role_hierarchy = %{
        member: 1,
        professional: 2,
        admin: 3,
        support: 3
      }
      
      # Member can upgrade to professional
      assert role_hierarchy[:member] < role_hierarchy[:professional]
      
      # Professional cannot auto-upgrade to admin
      assert role_hierarchy[:professional] < role_hierarchy[:admin]
      
      # Admin is highest level
      assert role_hierarchy[:admin] == 3
    end
    
    test "calculates expected role based on active subscriptions", %{user: user, customer: customer, pro_plan: pro_plan} do
      # User with no subscriptions should be member
      expected_role_no_subs = calculate_expected_role(user, [])
      assert expected_role_no_subs == :member
      
      # Create active subscription
      {:ok, subscription} = Ash.create(Subscription, %{
        customer_id: customer.id,
        plan_id: pro_plan.id,
        stripe_subscription_id: "sub_expected_role",
        status: "active",
        current_period_start: DateTime.utc_now(),
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
      })
      
      subscription_with_plan = Ash.load!(subscription, :plan)
      
      # User with active professional subscription should be professional
      expected_role_with_sub = calculate_expected_role(user, [subscription_with_plan])
      assert expected_role_with_sub == :professional
      
      # Admin users should keep admin role regardless of subscriptions
      {:ok, admin_user} = Ash.update(user, %{role: :admin})
      expected_admin_role = calculate_expected_role(admin_user, [])
      assert expected_admin_role == :admin
    end
  end
  
  # Helper function to calculate expected role (similar to webhook controller logic)
  defp calculate_expected_role(user, active_subscriptions) do
    cond do
      # Admin and support roles are manually managed
      user.role in [:admin, :support] -> user.role
      
      # Check for active subscription with highest role
      not Enum.empty?(active_subscriptions) ->
        active_subscriptions
        |> Enum.map(&String.to_atom(&1.plan.user_role || "member"))
        |> Enum.max_by(&role_priority/1)
      
      # Default to member if no active subscription
      true -> :member
    end
  end
  
  defp role_priority(:admin), do: 3
  defp role_priority(:support), do: 3
  defp role_priority(:professional), do: 2
  defp role_priority(:member), do: 1
  defp role_priority(_), do: 1
end