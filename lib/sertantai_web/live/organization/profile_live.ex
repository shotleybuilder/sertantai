defmodule SertantaiWeb.Organization.ProfileLive do
  @moduledoc """
  LiveView for viewing and editing existing organization profile.
  """
  use SertantaiWeb, :live_view

  alias Sertantai.Organizations.Organization

  def mount(_params, session, socket) do
    # Load current user from session using AshAuthentication (same pattern as AuthLive)
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    current_user = socket.assigns[:current_user]

    if current_user do
      case load_user_organization(current_user.id) do
      {:ok, organization} ->
        form = AshPhoenix.Form.for_action(organization, :update, domain: Sertantai.Organizations)
        
        {:ok,
         socket
         |> assign(:page_title, "Organization Profile")
         |> assign(:organization, organization)
         |> assign(:form, to_form(form))
         |> assign(:editing, false)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:info, "You haven't registered an organization yet.")
         |> redirect(to: ~p"/organizations/register")}

        {:error, reason} ->
          {:ok,
           socket
           |> put_flash(:error, "Unable to load organization: #{inspect(reason)}")
           |> redirect(to: ~p"/dashboard")}
      end
    else
      # User not authenticated, redirect to login
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to access this page")
       |> redirect(to: ~p"/login")}
    end
  end

  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, :editing, !socket.assigns.editing)}
  end

  def handle_event("save", %{"form" => org_params}, socket) do
    organization = socket.assigns.organization
    
    # Extract organization attributes for the core_profile
    organization_attrs = %{
      "organization_name" => org_params["organization_name"],
      "organization_type" => org_params["organization_type"],
      "industry_sector" => org_params["industry_sector"],
      "headquarters_region" => org_params["headquarters_region"],
      "total_employees" => parse_integer(org_params["total_employees"]),
      "registration_number" => org_params["registration_number"],
      "primary_sic_code" => org_params["primary_sic_code"]
    }

    case Ash.update(organization, %{
      organization_name: org_params["organization_name"],
      organization_attrs: organization_attrs
    }, action: :update, domain: Sertantai.Organizations) do
      {:ok, updated_organization} ->
        form = AshPhoenix.Form.for_action(updated_organization, :update, domain: Sertantai.Organizations)
        
        {:noreply,
         socket
         |> assign(:organization, updated_organization)
         |> assign(:form, to_form(form))
         |> assign(:editing, false)
         |> put_flash(:info, "Organization profile updated successfully!")}

      {:error, error} ->
        # Create a new form for the original organization to reset the form state
        form = AshPhoenix.Form.for_action(organization, :update, domain: Sertantai.Organizations)
        
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, "Failed to update organization profile")}
    end
  end

  def handle_event("cancel", _params, socket) do
    organization = socket.assigns.organization
    form = AshPhoenix.Form.for_action(organization, :update, domain: Sertantai.Organizations)
    
    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:editing, false)}
  end

  defp load_user_organization(user_id) do
    case Ash.read(Organization, domain: Sertantai.Organizations) do
      {:ok, organizations} ->
        case Enum.find(organizations, &(&1.created_by_user_id == user_id)) do
          nil -> {:error, :not_found}
          organization -> {:ok, organization}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: nil

  # Number formatting helper
  defp format_number(nil), do: nil
  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end
  defp format_number(number), do: number

  # Formatting helper functions
  defp format_organization_type(type) do
    case type do
      "limited_company" -> "Limited Company"
      "public_limited_company" -> "Public Limited Company"
      "partnership" -> "Partnership"
      "sole_trader" -> "Sole Trader"
      "limited_liability_partnership" -> "Limited Liability Partnership"
      "charity" -> "Charity"
      "government_agency" -> "Government Agency"
      "other" -> "Other"
      _ -> type
    end
  end

  defp format_industry_sector(sector) do
    case sector do
      "construction" -> "Construction"
      "manufacturing" -> "Manufacturing"
      "technology" -> "Technology"
      "financial_services" -> "Financial Services"
      "healthcare" -> "Healthcare"
      "education" -> "Education"
      "retail" -> "Retail"
      "transportation" -> "Transportation"
      "agriculture" -> "Agriculture"
      "energy" -> "Energy"
      "other" -> "Other"
      _ -> sector
    end
  end

  defp format_region(region) do
    case region do
      "united_kingdom" -> "United Kingdom"
      "england" -> "England"
      "scotland" -> "Scotland"
      "wales" -> "Wales"
      "northern_ireland" -> "Northern Ireland"
      "european_union" -> "European Union"
      "united_states" -> "United States"
      "other" -> "Other"
      _ -> region
    end
  end
end