defmodule Sertantai.Billing.PlanTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.Plan
  
  require Ash.Query
  import Ash.Expr
  
  describe "Plan resource" do
    setup do
      # Create a test admin user to use as actor
      {:ok, admin_user} = Ash.create(Sertantai.Accounts.User, %{
        email: "admin@test.local",
        password: "test123",
        password_confirmation: "test123",
        role: :admin
      }, action: :register_with_password)
      
      {:ok, admin_user: admin_user}
    end
    
    test "creates a plan with valid attributes", %{admin_user: admin_user} do
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
      
      assert {:ok, plan} = Ash.create(Plan, attrs, actor: admin_user)
      assert plan.name == "Professional Plan"
      assert plan.stripe_price_id == "price_1234567890"
      assert Decimal.equal?(plan.amount, Decimal.new("29.99"))
      assert plan.currency == "usd"
      assert plan.interval == :month
      assert plan.user_role == :professional
      assert plan.active == true
      assert plan.features == ["AI Features", "Sync Tools", "Priority Support"]
    end
    
    test "fails to create plan without required fields", %{admin_user: admin_user} do
      attrs = %{
        name: "Test Plan"
        # Missing required fields
      }
      
      assert {:error, _} = Ash.create(Plan, attrs, actor: admin_user)
    end
    
    test "updates a plan", %{admin_user: admin_user} do
      {:ok, plan} = Ash.create(Plan, %{
        name: "Basic Plan",
        stripe_price_id: "price_basic",
        amount: 19.99,
        currency: "usd",
        interval: "month",
        user_role: "member"
      }, actor: admin_user)
      
      assert {:ok, updated_plan} = Ash.update(plan, %{amount: 24.99, active: false}, actor: admin_user)
      assert Decimal.equal?(updated_plan.amount, Decimal.new("24.99"))
      assert updated_plan.active == false
    end
    
    test "reads plans with filters", %{admin_user: admin_user} do
      # Create multiple plans
      {:ok, active_plan} = Ash.create(Plan, %{
        name: "Active Plan",
        stripe_price_id: "price_active",
        amount: 29.99,
        currency: "usd",
        interval: "month",
        user_role: "professional",
        active: true
      }, actor: admin_user)
      
      {:ok, inactive_plan} = Ash.create(Plan, %{
        name: "Inactive Plan",
        stripe_price_id: "price_inactive",
        amount: 19.99,
        currency: "usd",
        interval: "month",
        user_role: "member",
        active: false
      }, actor: admin_user)
      
      # Query active plans
      active_plans = Plan
        |> Ash.Query.filter(active == true)
        |> Ash.read!(actor: admin_user)
        
      assert length(active_plans) >= 1
      assert Enum.any?(active_plans, &(&1.id == active_plan.id))
      refute Enum.any?(active_plans, &(&1.id == inactive_plan.id))
    end
    
    test "deletes a plan", %{admin_user: admin_user} do
      {:ok, plan} = Ash.create(Plan, %{
        name: "Temp Plan",
        stripe_price_id: "price_temp",
        amount: 9.99,
        currency: "usd",
        interval: "month",
        user_role: "member"
      }, actor: admin_user)
      
      assert :ok = Ash.destroy(plan, actor: admin_user)
      
      # Verify it's deleted
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} = Ash.get(Plan, plan.id, actor: admin_user)
    end
  end
end