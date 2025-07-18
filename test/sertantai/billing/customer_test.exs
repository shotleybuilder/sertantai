defmodule Sertantai.Billing.CustomerTest do
  use Sertantai.DataCase
  
  alias Sertantai.Billing
  alias Sertantai.Billing.Customer
  alias Sertantai.Accounts
  alias Sertantai.Accounts.User
  
  require Ash.Query
  import Ash.Expr
  
  setup do
    # Create a test admin user to use as actor
    {:ok, admin_user} = Ash.create(User, %{
      email: "admin@test.local",
      password: "test123",
      password_confirmation: "test123",
      role: :admin
    }, action: :register_with_password)
    
    # Create a test user
    {:ok, user} = Ash.create(User, %{
      email: "test@example.com",
      password: "test123",
      password_confirmation: "test123",
      role: :member
    }, action: :register_with_password, actor: admin_user)
    
    {:ok, admin_user: admin_user, user: user}
  end
  
  describe "Customer resource" do
    test "creates a customer linked to user", %{admin_user: admin_user, user: user} do
      attrs = %{
        user_id: user.id,
        stripe_customer_id: "cus_test123",
        email: user.email,
        name: "Test Customer",
        phone: "+1234567890",
        company: "Test Company",
        address: %{
          line1: "123 Test St",
          city: "Test City",
          state: "TS",
          postal_code: "12345",
          country: "US"
        }
      }
      
      assert {:ok, customer} = Ash.create(Customer, attrs, actor: admin_user)
      assert customer.user_id == user.id
      assert customer.stripe_customer_id == "cus_test123"
      assert customer.email == user.email
      assert customer.name == "Test Customer"
      assert customer.address["city"] == "Test City"
    end
    
    test "enforces unique stripe_customer_id", %{admin_user: admin_user, user: user} do
      attrs = %{
        user_id: user.id,
        stripe_customer_id: "cus_unique",
        email: user.email
      }
      
      assert {:ok, _customer1} = Ash.create(Customer, attrs, actor: admin_user)
      
      # Try to create another with same stripe_customer_id
      {:ok, user2} = Ash.create(User, %{
        email: "another@example.com",
        password: "test123",
        password_confirmation: "test123",
        role: :member
      }, action: :register_with_password, actor: admin_user)
      
      attrs2 = %{
        user_id: user2.id,
        stripe_customer_id: "cus_unique",
        email: user2.email
      }
      
      assert {:error, _} = Ash.create(Customer, attrs2, actor: admin_user)
    end
    
    test "loads user relationship", %{admin_user: admin_user, user: user} do
      {:ok, customer} = Ash.create(Customer, %{
        user_id: user.id,
        stripe_customer_id: "cus_rel",
        email: user.email
      }, actor: admin_user)
      
      loaded_customer = Ash.load!(customer, :user, actor: admin_user)
      assert loaded_customer.user.id == user.id
      assert loaded_customer.user.email == user.email
    end
    
    test "queries customers by stripe_customer_id", %{admin_user: admin_user, user: user} do
      {:ok, customer} = Ash.create(Customer, %{
        user_id: user.id,
        stripe_customer_id: "cus_query",
        email: user.email
      }, actor: admin_user)
      
      found_customer = Customer
        |> Ash.Query.filter(stripe_customer_id == "cus_query")
        |> Ash.read_one!(actor: admin_user)
        
      assert found_customer.id == customer.id
    end
    
    test "updates customer information", %{admin_user: admin_user, user: user} do
      {:ok, customer} = Ash.create(Customer, %{
        user_id: user.id,
        stripe_customer_id: "cus_update",
        email: user.email
      }, actor: admin_user)
      
      assert {:ok, updated} = Ash.update(customer, %{
        name: "Updated Name",
        phone: "+9876543210"
      }, actor: admin_user)
      
      assert updated.name == "Updated Name"
      assert updated.phone == "+9876543210"
    end
  end
end