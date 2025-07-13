defmodule Sertantai.Sync do
  @moduledoc """
  Sync domain for managing external database synchronization.
  Handles sync configurations, selected records, and sync operations.
  """
  
  use Ash.Domain,
    extensions: [AshAdmin.Domain]

  resources do
    resource Sertantai.Sync.SyncConfiguration
    resource Sertantai.Sync.SelectedRecord
  end

  # Admin configuration
  admin do
    show? true
  end
end