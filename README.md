# Muadzin

An Islamic prayer times scheduler and azan player for Nerves-based embedded devices (Raspberry Pi, etc.). Features a Phoenix web interface for monitoring and configuration.

## Features

- Automatic prayer time calculation based on location and timezone
- Plays azan (call to prayer) at scheduled times
- Web interface for monitoring and settings
- REST API for integration with Home Assistant and other systems
- Real-time updates via LiveView
- Supports multiple hardware platforms (Raspberry Pi, BeagleBone, etc.)

## Home Assistant Integration

See the [`home_assistant/`](home_assistant/) folder for complete integration instructions, including:
- Sensor configuration for prayer times
- Tappable dashboard cards
- Automation examples
- Control buttons for azan playback

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/targets.html#content

## Getting Started

To start your Nerves app:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix burn`

## Learn more

  * Official docs: https://hexdocs.pm/nerves/getting-started.html
  * Official website: https://nerves-project.org/
  * Forum: https://elixirforum.com/c/nerves-forum
  * Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
  * Source: https://github.com/nerves-project/nerves
