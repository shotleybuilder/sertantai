defmodule Sertantai.OrganizationsFixtures do
  @moduledoc """
  This module defines test helpers for creating organizations for testing.
  """

  alias Sertantai.Organizations.Organization

  def organization_fixture(attrs \\ %{}) do
    organization_attrs = %{
      "organization_name" => "Test Organization Ltd",
      "organization_type" => "limited_company",
      "industry_sector" => "technology",
      "headquarters_region" => "united_kingdom",
      "total_employees" => 100
    }

    default_attrs = %{
      email_domain: "example.com",
      organization_name: "Test Organization Ltd",
      created_by_user_id: Ecto.UUID.generate(),
      organization_attrs: organization_attrs
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    # Extract actor from attrs and pass it separately
    {actor, merged_attrs} = Map.pop(merged_attrs, :actor)

    {:ok, organization} = 
      if actor do
        Ash.create(Organization, merged_attrs, domain: Sertantai.Organizations, actor: actor)
      else
        Ash.create(Organization, merged_attrs, domain: Sertantai.Organizations)
      end

    organization
  end

  def minimal_organization_fixture(attrs \\ %{}) do
    organization_attrs = %{
      "organization_name" => "Minimal Org",
      "organization_type" => "sole_trader",
      "industry_sector" => "other",
      "headquarters_region" => "england"
    }

    minimal_attrs = %{
      email_domain: "minimal.com",
      organization_name: "Minimal Org",
      created_by_user_id: Ecto.UUID.generate(),
      organization_attrs: organization_attrs
    }

    merged_attrs = Map.merge(minimal_attrs, attrs)

    {:ok, organization} = 
      Ash.create(Organization, merged_attrs, domain: Sertantai.Organizations)

    organization
  end

  def complete_organization_fixture(attrs \\ %{}) do
    organization_attrs = %{
      "organization_name" => "Complete Organization Ltd",
      "organization_type" => "limited_company",
      "industry_sector" => "manufacturing",
      "headquarters_region" => "scotland",
      "total_employees" => 500,
      "registration_number" => "12345678",
      "primary_sic_code" => "29100"
    }

    complete_attrs = %{
      email_domain: "complete.com",
      organization_name: "Complete Organization Ltd",
      created_by_user_id: Ecto.UUID.generate(),
      organization_attrs: organization_attrs
    }

    merged_attrs = Map.merge(complete_attrs, attrs)

    {:ok, organization} = 
      Ash.create(Organization, merged_attrs, domain: Sertantai.Organizations)

    organization
  end
end