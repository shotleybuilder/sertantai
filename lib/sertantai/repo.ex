defmodule Sertantai.Repo do
  use Ecto.Repo,
    otp_app: :sertantai,
    adapter: Ecto.Adapters.Postgres
end
