defmodule Sertantai.Sync do
  @moduledoc """
  Sync domain for managing external database synchronization.
  Handles sync configurations, selected records, and sync operations.
  """
  
  use Ash.Domain

  resources do
    resource Sertantai.Sync.SyncConfiguration
    resource Sertantai.Sync.SelectedRecord
  end
end