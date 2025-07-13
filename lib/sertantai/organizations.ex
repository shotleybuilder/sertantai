defmodule Sertantai.Organizations do
  @moduledoc """
  The Organizations domain handles organization management and 
  applicability screening for Phase 1 implementation.
  """

  use Ash.Domain

  resources do
    resource Sertantai.Organizations.Organization
    resource Sertantai.Organizations.OrganizationUser
    resource Sertantai.Organizations.OrganizationLocation
    resource Sertantai.Organizations.LocationScreening
  end
end