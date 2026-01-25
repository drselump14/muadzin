import Config

# Add configuration that is only needed when running on the host here.

# Use console logger only for host development
config :logger,
  backends: [:console],
  level: :debug

# Configure Phoenix endpoint for development on host
config :muadzin, MuadzinWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  debug_errors: true,
  check_origin: false,
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]
