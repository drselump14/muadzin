# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

audio_player_cmd = if Mix.target() in [:rpi, :rpi2, :rpi3], do: "aplay", else: "afplay"

audio_player_args =
  if Mix.target() in [:rpi, :rpi2, :rpi3], do: ["-q"], else: []

config :muadzin,
  target: Mix.target(),
  audio_player_cmd: audio_player_cmd,
  audio_player_args: audio_player_args

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1668861439"

config :logger, :logger_papertrail_backend,
  url: System.get_env("PAPERTRAIL_URL"),
  level: :debug,
  format: "$time $metadata[$level] $message"

config :logger,
  backends: [:console, LoggerPapertrailBackend.Logger],
  level: :debug

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
