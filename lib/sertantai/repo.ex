defmodule Sertantai.Repo do
  use AshPostgres.Repo, otp_app: :sertantai

  def installed_extensions do
    # Add your extensions here if needed
    ["ash-functions", "uuid-ossp"]
  end
end
