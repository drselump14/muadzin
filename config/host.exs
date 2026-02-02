import Config

# Add configuration that is only needed when running on the host here.

# Use console logger only for host development
config :logger,
  backends: [:console],
  level: :debug

# Use test audio files by default on host (can override with USE_TEST_AUDIO=false)
config :muadzin,
  use_test_audio: System.get_env("USE_TEST_AUDIO", "true") == "true"

# Configure Phoenix endpoint for development on host
config :muadzin, MuadzinWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  debug_errors: true,
  check_origin: false,
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]
