defmodule Sertantai.Billing.PlanTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.Plan
  
  describe "Plan resource" do
    test "creates a plan with valid attributes" do
      attrs = %{
        name: "Professional Plan",
        stripe_price_id: "price_1234567890",
        amount: 29.99,
        currency: "usd",
        interval: "month",
        user_role: "professional",
        active: true,
        features: ["AI Features", "Sync Tools", "Priority Support"]
      }
      
      assert {:ok, plan} = Ash.create(Plan, attrs)
      assert plan.name == "Professional Plan"
      assert plan.stripe_price_id == "price_1234567890"
      assert plan.amount == 29.99
      assert plan.currency == "usd"
      assert plan.interval == "month"
      assert plan.user_role == "professional"
      assert plan.active == true
      assert plan.features == ["AI Features", "Sync Tools", "Priority Support"]
    end
    
    test "fails to create plan without required fields" do
      attrs = %{
        name: "Test Plan"
        # Missing required fields
      }
      
      assert {:error, _} = Ash.create(Plan, attrs)
    end
    
    test "updates a plan" do
      {:ok, plan} = Ash.create(Plan, %{
        name: "Basic Plan",
        stripe_price_id: "price_basic",
        amount: 19.99,
        currency: "usd",
        interval: "month",
        user_role: "member"
      })
      
      assert {:ok, updated_plan} = Ash.update(plan, %{amount: 24.99, active: false})
      assert updated_plan.amount == 24.99
      assert updated_plan.active == false
    end
    
    test "reads plans with filters" do
      # Create multiple plans
      {:ok, active_plan} = Ash.create(Plan, %{
        name: "Active Plan",
        stripe_price_id: "price_active",
        amount: 29.99,
        currency: "usd",
        interval: "month",
        user_role: "professional",
        active: true
      })
      
      {:ok, inactive_plan} = Ash.create(Plan, %{
        name: "Inactive Plan",
        stripe_price_id: "price_inactive",
        amount: 19.99,
        currency: "usd",
        interval: "month",
        user_role: "member",
        active: false
      })
      
      # Query active plans
      active_plans = Plan
        |> Ash.Query.filter(active == true)
        |> Ash.read!()
        
      assert length(active_plans) >= 1
      assert Enum.any?(active_plans, &(&1.id == active_plan.id))
      refute Enum.any?(active_plans, &(&1.id == inactive_plan.id))
    end
    
    test "deletes a plan" do
      {:ok, plan} = Ash.create(Plan, %{
        name: "Temp Plan",
        stripe_price_id: "price_temp",
        amount: 9.99,
        currency: "usd",
        interval: "month",
        user_role: "member"
      })
      
      assert :ok = Ash.destroy(plan)
      
      # Verify it's deleted
      assert {:error, %Ash.Error.Query.NotFound{}} = Ash.get(Plan, plan.id)
    end
  end
end