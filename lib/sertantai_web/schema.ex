defmodule Sertantai.Schema do
  @moduledoc """
  GraphQL schema for the Sertantai application.
  """
  
  use Absinthe.Schema
  
  @domains [Sertantai.Domain]

  use AshGraphql, domains: @domains

  query do
    # These queries will be automatically generated from the Ash domain
  end

  mutation do
    # These mutations will be automatically generated from the Ash domain
  end
end