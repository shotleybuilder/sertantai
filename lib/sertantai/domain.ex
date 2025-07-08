defmodule Sertantai.Domain do
  @moduledoc """
  Main Ash domain for the Sertantai application.
  Contains all resources and manages their interactions.
  """
  
  use Ash.Domain,
    extensions: [AshGraphql.Domain, AshJsonApi.Domain]

  resources do
    resource Sertantai.UkLrt
    resource Sertantai.SyncConfig
  end

  # GraphQL configuration
  graphql do
    authorize? false
  end

  # JSON API configuration
  json_api do
    authorize? false
  end
end