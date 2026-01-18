# Muadzin Project - AI Agent Instructions

## Project Overview

**Muadzin** is an Elixir Nerves IoT application that automatically plays the Islamic call to prayer (Adhan/Azan) at scheduled prayer times. It runs on embedded hardware devices like Raspberry Pi.

### Key Characteristics
- **Framework**: Nerves (Elixir IoT framework)
- **Target Hardware**: Raspberry Pi (rpi, rpi0, rpi2, rpi3, rpi3a, rpi4), BeagleBone Black, x86_64, and others
- **Elixir Version**: ~> 1.14
- **Development Environment**: Managed by Devbox + Mise

## Architecture

### Core Components

1. **Muadzin.Application** (`lib/muadzin/application.ex`)
   - OTP Application entry point
   - Supervisor for all child processes
   - Conditional children based on target (`:host` vs actual hardware)

2. **Muadzin.Scheduler** (`lib/muadzin/scheduler.ex`)
   - GenServer that manages prayer time scheduling
   - Calculates prayer times using `azan_ex` library
   - Schedules and plays azan audio at appropriate times
   - Plays dua (supplication) after azan
   - Currently configured for Tokyo, Japan (latitude: 35.67, longitude: 139.90)

### Prayer Time Logic
- Uses Muslim World League calculation method
- Supports all 5 daily prayers (Fajr, Dhuhr, Asr, Maghrib, Isha)
- Also tracks Sunrise and Sunset (no azan played for these)
- Different azan audio for Fajr vs other prayers
- Automatically schedules next day's Fajr after Isha

## Development Environment Setup

### Devbox Configuration
The project uses **Devbox** for reproducible development environments:

```json
{
  "packages": [
    "mise@latest",
    "just@latest"
  ]
}
```

### Mise Integration
- Devbox initializes Mise for managing Elixir/Erlang versions
- All Mise data is stored locally in `.devbox/` directory
- Configuration files:
  - `.mise.toml` (if exists) - defines Elixir/Erlang versions
  - `.tool-versions` (deleted) - migrated to Mise

### Getting Started
1. Install Devbox: `curl -fsSL https://get.jetify.com/devbox | bash`
2. Enter dev shell: `devbox shell`
3. Mise will automatically install required Elixir/Erlang versions
4. Install dependencies: `mix deps.get`

## Building and Deployment

### Nerves Targets
Set target before building firmware:
```bash
export MIX_TARGET=rpi3  # or rpi4, rpi0, etc.
```

### Common Commands
```bash
# Install dependencies
mix deps.get

# Build firmware
mix firmware

# Burn to SD card
mix burn

# Create firmware bundle
mix firmware.gen.script
```

## Key Dependencies

### Core Nerves
- `nerves ~> 1.10` - Core framework
- `nerves_runtime ~> 0.13.0` - Runtime utilities
- `nerves_pack ~> 0.7.0` - Network and SSH support
- `shoehorn ~> 0.9.1` - Boot strategy
- `ring_logger ~> 0.11.3` - Ring buffer logging

### Application Logic
- `azan_ex ~> 0.3.0` - Prayer time calculations
- `typed_struct ~> 0.3.0` - Type-safe structs
- `logger_papertrail_backend ~> 1.0` - Remote logging

### Development
- `dialyxir ~> 1.0` - Static analysis (Dialyzer)
- `toolshed ~> 0.4.2` - IEx helpers for Nerves

## Audio System

### Audio Configuration
The project uses ALSA (amixer) for audio control:
- Output device: Card 1 (HDMI/analog out on RPi)
- Volume: 90%

### Audio Files
Audio files should be placed in `priv/` directory:
- `azan.wav` - Standard azan for Dhuhr, Asr, Maghrib, Isha
- `azan-fajr.wav` - Fajr-specific azan
- `dua-after-the-azan.wav` - Dua played after azan

### Audio Player Configuration
Set in `config/target.exs`:
```elixir
config :muadzin,
  audio_player_cmd: "aplay",  # or "ffplay", etc.
  audio_player_args: []
```

## Configuration

### Location Settings
To change prayer time location, modify `lib/muadzin/scheduler.ex`:
```elixir
@latitude 35.67220046284479
@longitude 139.90246423845966
@timezone "Asia/Tokyo"
```

### Calculation Method
Default: Muslim World League
Other methods available from `Azan.CalculationMethod`:
- `north_america()`
- `egyptian()`
- `karachi()`
- `umm_al_qura()`
- `dubai()`
- `kuwait()`
- `qatar()`
- `singapore()`

## Code Conventions

### Style Guidelines
1. Use TypedStruct for GenServer state
2. Follow Elixir naming conventions (snake_case)
3. Use `@moduledoc` and `@doc` for documentation
4. Type specs with `@spec` where appropriate
5. Logger for runtime information

### Testing
- Unit tests: `mix test`
- On-device testing: Use IEx via SSH after deployment

### Git Workflow
- Main branch: `main`
- Commit messages should be clear and descriptive
- User has custom git aliases:
  - `gc`: git commit (without Claude contribution)
  - `gp`: git push origin
  - `glm`: glab-merge-clean (GitLab merge utility)

## Common Development Tasks

### When Adding New Features
1. Consider target environment (`:host` vs hardware)
2. Test on actual hardware when possible
3. Use Logger extensively for debugging on device
4. Keep in mind embedded constraints (memory, storage)

### When Modifying Prayer Logic
1. Test timezone conversions carefully
2. Verify calculation methods match user's location requirements
3. Test edge cases (midnight rollover, DST changes)
4. Ensure audio playback works on target hardware

### When Updating Dependencies
1. Check Nerves compatibility
2. Test firmware size (embedded systems have storage limits)
3. Verify on actual hardware, not just `:host` target
4. Update documentation if new features are available

## Troubleshooting

### Common Issues
1. **Audio not playing**: Check amixer settings, verify audio file paths
2. **Prayer times incorrect**: Verify timezone, coordinates, calculation method
3. **Firmware too large**: Remove unused dependencies, check for large assets
4. **Build failures**: Ensure MIX_TARGET is set, clean build with `mix clean`

### Debugging on Device
- SSH into device after burning firmware with networking enabled
- Use IEx: `ssh nerves.local` (password: depends on config)
- Check logs: RingLogger stores recent logs in memory
- View state: `GenServer.call(Muadzin.Scheduler, :fetch_state)`

## Important Notes for AI Agents

1. **Never modify coordinates without user confirmation** - Prayer times are location-specific
2. **Preserve audio file paths** - These must match files in `priv/` directory
3. **Respect Nerves conventions** - Target-specific code goes in `children/1` clauses
4. **Test changes carefully** - Running on embedded hardware, debugging is harder
5. **Keep it simple** - Embedded systems have resource constraints
6. **Devbox/Mise workflow** - Always use `devbox shell` for development commands
7. **Timezone awareness** - All prayer time calculations must respect configured timezone

## Resources

- [Nerves Documentation](https://hexdocs.pm/nerves/getting-started.html)
- [Nerves Project](https://nerves-project.org/)
- [azan_ex Library](https://hexdocs.pm/azan_ex/)
- [Devbox Documentation](https://www.jetify.com/devbox/docs/)
- [Mise Documentation](https://mise.jdx.dev/)
