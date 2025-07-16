import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :sertantai, Sertantai.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sertantai_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  ownership_timeout: 120_000,
  queue_target: 5000,
  queue_interval: 10_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sertantai, SertantaiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ZQklR7ZyockF00i3+7RpPgnQ57L4ZL8JgOUta5nMb+EID5VclNdEzoLZKdcwtYP4",
  server: false

# In test we don't send emails
config :sertantai, Sertantai.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
