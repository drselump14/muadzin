# Home Assistant Integration for Muadzin

This guide explains how to integrate your Muadzin prayer times system with Home Assistant.

## Overview

The Muadzin application now exposes several REST API endpoints that Home Assistant can consume to:
- Display prayer times
- Show countdown to next prayer
- Control azan playback (stop/trigger)
- Create automations based on prayer times

## API Endpoints

### GET Endpoints (Read Data)
- `GET /api/prayers` - Get all daily prayer times
- `GET /api/next-prayer` - Get next prayer info with countdown

### POST Endpoints (Control Actions)
- `POST /api/azan/stop` - Stop currently playing azan
- `POST /api/azan/trigger` - Manually trigger azan playback

## Setup Instructions

### 1. Find Your Muadzin Device Address

Your device should be accessible at one of these addresses:
- `http://muadzin.local` (via mDNS)
- `http://<IP_ADDRESS>` (if you know the IP)

Test the API by visiting in your browser:
```
http://muadzin.local/api/prayers
```

### 2. Add Configuration to Home Assistant

Copy the contents of `configuration.yaml` (in this folder) to your Home Assistant configuration.

You can either:

**Option A: Add to main configuration.yaml**
```bash
# Copy the contents directly into your configuration.yaml
```

**Option B: Use packages (recommended)**
```yaml
# In configuration.yaml, enable packages:
homeassistant:
  packages: !include_dir_named packages

# Then create packages/muadzin.yaml with the configuration
```

### 3. Update the Device Address

In the configuration file, replace `muadzin.local` with your actual device address:

```yaml
rest:
  - resource: http://YOUR_DEVICE_ADDRESS/api/prayers
```

### 4. Restart Home Assistant

After adding the configuration:
1. Go to **Settings** → **System** → **Restart**
2. Wait for Home Assistant to restart

### 5. Verify Integration

Check that the sensors are available:
1. Go to **Developer Tools** → **States**
2. Search for `muadzin` or `prayer`
3. You should see sensors like:
   - `sensor.prayer_times`
   - `sensor.next_prayer`
   - `sensor.fajr_prayer_time`
   - etc.

## Available Entities

### Sensors
- **sensor.next_prayer** - Name of the next prayer (fajr, dhuhr, asr, maghrib, isha)
- **sensor.current_prayer** - Name of the current prayer period
- **sensor.time_to_next_azan** - Minutes until next azan
- **sensor.fajr_prayer_time** - Fajr prayer time
- **sensor.dhuhr_prayer_time** - Dhuhr prayer time
- **sensor.asr_prayer_time** - Asr prayer time
- **sensor.maghrib_prayer_time** - Maghrib prayer time
- **sensor.isha_prayer_time** - Isha prayer time

### Binary Sensors
- **binary_sensor.azan_is_playing** - True when azan is playing

### Buttons
- **button.stop_azan** - Stop currently playing azan
- **button.trigger_azan** - Manually trigger azan

## Example Lovelace Dashboard

### Quick Setup: Tappable Prayer Times Card

**See `lovelace_cards.yaml` for ready-to-use dashboard configurations!**

The easiest way to add prayer times to your dashboard with tap-to-expand functionality:

#### Option 1: Expandable Entity Card (Recommended - No custom cards needed!)

```yaml
type: entities
title: 🕌 Prayer Times
show_header_toggle: false
state_color: true
entities:
  # Tap this to expand and see all prayer times
  - type: custom:fold-entity-row
    head:
      entity: sensor.next_prayer
      name: Next Prayer
      icon: mdi:mosque
    padding: 0
    entities:
      - entity: sensor.fajr_prayer_time
        name: 🌅 Fajr
      - entity: sensor.dhuhr_prayer_time
        name: 🌞 Dhuhr
      - entity: sensor.asr_prayer_time
        name: 🌤️ Asr
      - entity: sensor.maghrib_prayer_time
        name: 🌇 Maghrib
      - entity: sensor.isha_prayer_time
        name: 🌙 Isha

  - entity: sensor.time_to_next_azan
    name: Time Remaining
    icon: mdi:clock-outline

  - entity: binary_sensor.azan_is_playing
    name: Azan Playing
```

**How it works**: Tap the "Next Prayer" row to expand and see all 5 daily prayer times!

#### Option 2: Beautiful Markdown Card (Auto-updates)

```yaml
type: markdown
title: 🕌 Prayer Times
content: |
  **Next: {{ states('sensor.next_prayer') | title }}** in **{{ states('sensor.time_to_next_azan') }}** minutes

  ---

  | Prayer | Time |
  |--------|------|
  | 🌅 Fajr | {{ states('sensor.fajr_prayer_time') | as_timestamp | timestamp_custom('%I:%M %p', true) }} |
  | 🌞 Dhuhr | {{ states('sensor.dhuhr_prayer_time') | as_timestamp | timestamp_custom('%I:%M %p', true) }} |
  | 🌤️ Asr | {{ states('sensor.asr_prayer_time') | as_timestamp | timestamp_custom('%I:%M %p', true) }} |
  | 🌇 Maghrib | {{ states('sensor.maghrib_prayer_time') | as_timestamp | timestamp_custom('%I:%M %p', true) }} |
  | 🌙 Isha | {{ states('sensor.isha_prayer_time') | as_timestamp | timestamp_custom('%I:%M %p', true) }} |

  {% if is_state('binary_sensor.azan_is_playing', 'on') %}
  🔊 **Azan is currently playing**
  {% endif %}
```

**How it works**: Shows all prayer times at once in a clean table format that updates automatically!

#### Option 3: Grid Layout (All prayers visible)

```yaml
type: vertical-stack
cards:
  # Header
  - type: markdown
    content: |
      ## 🕌 Next: {{ states('sensor.next_prayer') | title }}
      ⏱️ In {{ states('sensor.time_to_next_azan') }} minutes

  # Grid of prayer times
  - type: grid
    columns: 2
    square: false
    cards:
      - type: button
        entity: sensor.fajr_prayer_time
        name: Fajr
        icon: mdi:weather-sunset-up
        show_state: true
      - type: button
        entity: sensor.dhuhr_prayer_time
        name: Dhuhr
        icon: mdi:white-balance-sunny
        show_state: true
      - type: button
        entity: sensor.asr_prayer_time
        name: Asr
        icon: mdi:weather-partly-cloudy
        show_state: true
      - type: button
        entity: sensor.maghrib_prayer_time
        name: Maghrib
        icon: mdi:weather-sunset-down
        show_state: true
      - type: button
        entity: sensor.isha_prayer_time
        name: Isha
        icon: mdi:weather-night
        show_state: true
      - type: button
        entity: binary_sensor.azan_is_playing
        name: Status
        show_state: true

  # Control buttons
  - type: horizontal-stack
    cards:
      - type: button
        name: Stop
        icon: mdi:stop-circle
        tap_action:
          action: call-service
          service: rest_command.muadzin_stop_azan
      - type: button
        name: Test
        icon: mdi:play-circle
        tap_action:
          action: call-service
          service: rest_command.muadzin_trigger_azan
```

### How to Add Cards to Dashboard

1. Go to your Home Assistant dashboard
2. Click the three dots (⋮) in the top right corner
3. Click **"Edit Dashboard"**
4. Click **"+ ADD CARD"**
5. Scroll to the bottom and click **"Manual"**
6. Paste one of the configurations above
7. Click **"Save"**

## Example Automations

### Notify Before Prayer Time

```yaml
automation:
  - alias: "Prayer Time Reminder"
    trigger:
      - platform: template
        value_template: "{{ states('sensor.time_to_next_azan') | int == 5 }}"
    action:
      - service: notify.mobile_app_your_phone
        data:
          title: "Prayer Time Soon"
          message: "{{ states('sensor.next_prayer') | title }} prayer in 5 minutes"
```

### Pause Media During Azan

```yaml
automation:
  - alias: "Pause Media During Azan"
    trigger:
      - platform: state
        entity_id: binary_sensor.azan_is_playing
        to: "on"
    action:
      - service: media_player.media_pause
        target:
          entity_id: all
```

### Daily Prayer Times Notification

```yaml
automation:
  - alias: "Daily Prayer Times"
    trigger:
      - platform: time
        at: "06:00:00"
    action:
      - service: notify.mobile_app_your_phone
        data:
          title: "Today's Prayer Times"
          message: |
            Fajr: {{ states('sensor.fajr_prayer_time') | as_timestamp | timestamp_custom('%H:%M') }}
            Dhuhr: {{ states('sensor.dhuhr_prayer_time') | as_timestamp | timestamp_custom('%H:%M') }}
            Asr: {{ states('sensor.asr_prayer_time') | as_timestamp | timestamp_custom('%H:%M') }}
            Maghrib: {{ states('sensor.maghrib_prayer_time') | as_timestamp | timestamp_custom('%H:%M') }}
            Isha: {{ states('sensor.isha_prayer_time') | as_timestamp | timestamp_custom('%H:%M') }}
```

## Advanced: Voice Control

If you have Google Assistant or Alexa integrated:

```yaml
# In configuration.yaml
intent_script:
  NextPrayerTime:
    speech:
      text: "The next prayer is {{ states('sensor.next_prayer') }} in {{ states('sensor.time_to_next_azan') }} minutes"

  StopAzan:
    action:
      - service: rest_command.muadzin_stop_azan
    speech:
      text: "Stopping the azan"
```

Then you can say:
- "Hey Google, ask Home Assistant when is the next prayer"
- "Alexa, tell Home Assistant to stop the azan"

## Troubleshooting

### Sensors Not Appearing
1. Check that the device is accessible: `curl http://muadzin.local/api/prayers`
2. Check Home Assistant logs for errors
3. Verify the device address is correct in configuration

### Prayer Times Not Updating
1. Check the `scan_interval` setting (default 60 seconds)
2. Verify the API is returning data
3. Check for network connectivity issues

### Control Buttons Not Working
1. Test the endpoint directly: `curl -X POST http://muadzin.local/api/azan/stop`
2. Check Home Assistant logs for REST command errors
3. Verify CORS is enabled (already configured in Muadzin)

## API Response Examples

### GET /api/prayers
```json
{
  "prayers": [
    {
      "name": "fajr",
      "time": "2025-02-01T04:30:00Z",
      "is_current": false,
      "is_next": true
    }
  ],
  "next_prayer_name": "fajr",
  "current_prayer_name": "isha",
  "time_to_next_azan_minutes": 120,
  "azan_playing": false
}
```

### GET /api/next-prayer
```json
{
  "next_prayer_name": "dhuhr",
  "next_prayer_time": "2025-02-01T12:34:56Z",
  "time_to_azan_minutes": 45,
  "time_to_azan_formatted": "45m",
  "current_prayer_name": "fajr",
  "azan_playing": false
}
```

### POST /api/azan/stop
```json
{
  "success": true,
  "message": "Azan stopped"
}
```

## Need Help?

- Check the Muadzin web interface at `http://muadzin.local`
- Review Home Assistant logs: **Settings** → **System** → **Logs**
- Test API endpoints with curl or your browser
