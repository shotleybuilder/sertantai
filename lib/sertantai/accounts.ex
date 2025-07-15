defmodule Sertantai.Accounts do
  @moduledoc """
  Accounts domain for managing user authentication and related resources.
  """
  
  use Ash.Domain,
    extensions: [AshAuthentication.Domain]

  resources do
    resource Sertantai.Accounts.User
    resource Sertantai.Accounts.Token
    resource Sertantai.Accounts.UserIdentity
  end

  # Authentication is handled by the domain extension
end
