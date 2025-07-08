defmodule Sertantai.Monitoring.SecurityMonitor do
  @moduledoc """
  Security monitoring and audit logging for the Sertantai application.
  Tracks security events, authentication attempts, and sensitive operations.
  """

  require Logger

  @doc """
  Log authentication attempt.
  """
  def log_auth_attempt(email, ip_address, user_agent, result) do
    log_security_event("authentication_attempt", %{
      email: email,
      ip_address: ip_address,
      user_agent: user_agent,
      result: result,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log successful authentication.
  """
  def log_auth_success(user_id, email, ip_address) do
    log_security_event("authentication_success", %{
      user_id: user_id,
      email: email,
      ip_address: ip_address,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log failed authentication.
  """
  def log_auth_failure(email, ip_address, reason) do
    log_security_event("authentication_failure", %{
      email: email,
      ip_address: ip_address,
      reason: reason,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log sync configuration access.
  """
  def log_sync_config_access(user_id, config_id, action) do
    log_security_event("sync_config_access", %{
      user_id: user_id,
      config_id: config_id,
      action: action,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log credential access or modification.
  """
  def log_credential_access(user_id, config_id, action) do
    log_security_event("credential_access", %{
      user_id: user_id,
      config_id: config_id,
      action: action,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log external API call.
  """
  def log_api_call(user_id, provider, endpoint, status, response_time) do
    log_security_event("external_api_call", %{
      user_id: user_id,
      provider: provider,
      endpoint: endpoint,
      status: status,
      response_time: response_time,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log rate limit violation.
  """
  def log_rate_limit_violation(user_id, limit_type, ip_address) do
    log_security_event("rate_limit_violation", %{
      user_id: user_id,
      limit_type: limit_type,
      ip_address: ip_address,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log sync operation.
  """
  def log_sync_operation(user_id, config_id, provider, record_count, status, duration) do
    log_security_event("sync_operation", %{
      user_id: user_id,
      config_id: config_id,
      provider: provider,
      record_count: record_count,
      status: status,
      duration: duration,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log security violation or suspicious activity.
  """
  def log_security_violation(user_id, violation_type, details) do
    log_security_event("security_violation", %{
      user_id: user_id,
      violation_type: violation_type,
      details: details,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log data access attempt.
  """
  def log_data_access(user_id, resource_type, resource_id, action) do
    log_security_event("data_access", %{
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      action: action,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Log encryption/decryption operation.
  """
  def log_encryption_operation(user_id, operation, resource_id, status) do
    log_security_event("encryption_operation", %{
      user_id: user_id,
      operation: operation,
      resource_id: resource_id,
      status: status,
      timestamp: DateTime.utc_now()
    })
  end

  # Private helper function to log security events
  defp log_security_event(event_type, event_data) do
    # Structured logging for security events
    Logger.info("SECURITY_EVENT", %{
      event_type: event_type,
      event_data: event_data,
      application: "sertantai",
      environment: Mix.env(),
      node: Node.self()
    })

    # Additional logging for critical events
    case event_type do
      "authentication_failure" ->
        Logger.warning("Authentication failure: #{event_data.email} from #{event_data.ip_address}")
      
      "rate_limit_violation" ->
        Logger.warning("Rate limit violation: #{event_data.limit_type} for user #{event_data.user_id}")
      
      "security_violation" ->
        Logger.error("Security violation: #{event_data.violation_type} for user #{event_data.user_id}")
      
      _ ->
        :ok
    end

    # In production, you might want to send to external monitoring service
    # send_to_monitoring_service(event_type, event_data)
  end

  # Example function for sending to external monitoring service
  # defp send_to_monitoring_service(event_type, event_data) do
  #   # Implementation depends on your monitoring service
  #   # Examples: Datadog, New Relic, Sentry, etc.
  # end
end