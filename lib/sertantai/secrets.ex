defmodule Sertantai.Secrets do
  @moduledoc """
  OAuth provider secrets management for AshAuthentication integration.
  
  This module provides secure access to OAuth provider credentials from
  environment variables, with fallbacks and validation for production use.
  """

  @doc """
  Get Google OAuth credentials.
  """
  def google_client_id(_path, _opts), do: get_env("GOOGLE_CLIENT_ID")
  def google_client_secret(_path, _opts), do: get_env("GOOGLE_CLIENT_SECRET")
  def google_redirect_uri(_path, _opts), do: get_env("GOOGLE_REDIRECT_URI")

  @doc """
  Get GitHub OAuth credentials.
  """
  def github_client_id(_path, _opts), do: get_env("GITHUB_CLIENT_ID")
  def github_client_secret(_path, _opts), do: get_env("GITHUB_CLIENT_SECRET")
  def github_redirect_uri(_path, _opts), do: get_env("GITHUB_REDIRECT_URI")

  @doc """
  Get Microsoft Azure OAuth credentials.
  """
  def azure_client_id(_path, _opts), do: get_env("AZURE_CLIENT_ID")
  def azure_client_secret(_path, _opts), do: get_env("AZURE_CLIENT_SECRET")
  def azure_redirect_uri(_path, _opts), do: get_env("AZURE_REDIRECT_URI")

  @doc """
  Get LinkedIn OAuth credentials.
  """
  def linkedin_client_id(_path, _opts), do: get_env("LINKEDIN_CLIENT_ID")
  def linkedin_client_secret(_path, _opts), do: get_env("LINKEDIN_CLIENT_SECRET")
  def linkedin_redirect_uri(_path, _opts), do: get_env("LINKEDIN_REDIRECT_URI")

  @doc """
  Get OKTA OIDC credentials.
  """
  def okta_client_id(_path, _opts), do: get_env("OKTA_CLIENT_ID")
  def okta_client_secret(_path, _opts), do: get_env("OKTA_CLIENT_SECRET")
  def okta_base_url(_path, _opts), do: get_env("OKTA_BASE_URL")
  def okta_redirect_uri(_path, _opts), do: get_env("OKTA_REDIRECT_URI")

  @doc """
  Get Airtable OAuth credentials.
  """
  def airtable_client_id(_path, _opts), do: get_env("AIRTABLE_CLIENT_ID")
  def airtable_client_secret(_path, _opts), do: get_env("AIRTABLE_CLIENT_SECRET")
  def airtable_redirect_uri(_path, _opts), do: get_env("AIRTABLE_REDIRECT_URI")

  # Private helper function
  defp get_env(key) do
    case System.get_env(key) do
      nil -> 
        {:error, "Missing environment variable: #{key}"}
      value when is_binary(value) and value != "" ->
        {:ok, value}
      _ ->
        {:error, "Invalid environment variable: #{key}"}
    end
  end

  @doc """
  Validate all OAuth provider configurations.
  Returns a map of provider => status for admin interface.
  """
  def validate_oauth_config do
    %{
      google: validate_provider([:google_client_id, :google_client_secret, :google_redirect_uri]),
      github: validate_provider([:github_client_id, :github_client_secret, :github_redirect_uri]),
      azure: validate_provider([:azure_client_id, :azure_client_secret, :azure_redirect_uri]),
      linkedin: validate_provider([:linkedin_client_id, :linkedin_client_secret, :linkedin_redirect_uri]),
      okta: validate_provider([:okta_client_id, :okta_client_secret, :okta_base_url, :okta_redirect_uri]),
      airtable: validate_provider([:airtable_client_id, :airtable_client_secret, :airtable_redirect_uri])
    }
  end

  defp validate_provider(required_functions) do
    results = Enum.map(required_functions, fn func ->
      apply(__MODULE__, func, [nil, []])
    end)

    if Enum.all?(results, fn result -> match?({:ok, _}, result) end) do
      :configured
    else
      errors = 
        results
        |> Enum.zip(required_functions)
        |> Enum.filter(fn {result, _func} -> match?({:error, _}, result) end)
        |> Enum.map(fn {{:error, msg}, _func} -> msg end)
      
      {:error, errors}
    end
  end

  @doc """
  Check if a specific OAuth provider is properly configured.
  """
  def provider_configured?(provider) when provider in [:google, :github, :azure, :linkedin, :okta, :airtable] do
    config = validate_oauth_config()
    match?(:configured, Map.get(config, provider))
  end
end