defmodule Sertantai.Accounts.Token do
  @moduledoc """
  Token resource for authentication using Ash Authentication.
  """
  
  use Ash.Resource,
    domain: Sertantai.Accounts,
    extensions: [AshAuthentication.TokenResource],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tokens"
    repo Sertantai.Repo
  end

  token do
    domain Sertantai.Accounts
  end
end
