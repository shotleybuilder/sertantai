defmodule SertantaiWeb.Applicability.SmartScreeningRouteLive do
  @moduledoc """
  Smart routing LiveView that redirects users to appropriate screening interface
  based on whether they have single or multiple locations.
  
  This provides intelligent routing that:
  - Single location orgs -> direct location screening
  - Multi-location orgs -> organization aggregate screening  
  - No locations -> location management page
  """
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations
  alias Sertantai.Organizations.{Organization, SingleLocationAdapter}
  require Ash.Query

  @impl true
  def mount(_params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    current_user = socket.assigns[:current_user]

    if current_user do
      case load_user_organization_with_locations(current_user.id) do
        {:ok, organization} ->
          {mode, route} = SingleLocationAdapter.get_screening_route(organization)
          
          case mode do
            :single_location ->
              {:ok, redirect(socket, to: route)}
            
            :multi_location ->
              {:ok, redirect(socket, to: route)}
            
            :no_locations ->
              {:ok,
               socket
               |> put_flash(:info, "Please add at least one location before running screening")
               |> redirect(to: route)}
            
            :error ->
              {:ok,
               socket
               |> put_flash(:error, "Unable to determine screening route. Please check your organization setup.")
               |> redirect(to: ~p"/organizations")}
          end

        {:error, :not_found} ->
          {:ok, 
           socket
           |> put_flash(:info, "Please register your organization first")
           |> redirect(to: ~p"/organizations/register")}
      end
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50">
      <div class="max-w-md w-full space-y-8">
        <div>
          <div class="mx-auto h-12 w-12 text-blue-600">
            <svg class="animate-spin h-12 w-12" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
          <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Determining best screening approach...
          </h2>
          <p class="mt-2 text-center text-sm text-gray-600">
            We're analyzing your organization setup to provide the most relevant screening experience.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp load_user_organization_with_locations(user_id) do
    Organization
    |> Ash.Query.filter(created_by_user_id == ^user_id)
    |> Ash.Query.load([:locations])
    |> Ash.read_one(domain: Organizations)
  end
end