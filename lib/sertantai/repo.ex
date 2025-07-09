defmodule Sertantai.Repo do
  use AshPostgres.Repo, otp_app: :sertantai

  def installed_extensions do
    # Add your extensions here if needed
    ["ash-functions", "uuid-ossp", "citext"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
