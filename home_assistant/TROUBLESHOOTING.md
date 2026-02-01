# Home Assistant Integration Troubleshooting

## Sensors Not Showing Up After Restart

Follow these steps in order to diagnose and fix the issue.

---

## Step 1: Check Configuration File Location

### Option A: Added to main configuration.yaml
If you added the configuration to your main `configuration.yaml`:

1. Make sure you added it at the **root level** (not indented under another section)
2. The `rest:` key should be at the same indentation level as `homeassistant:`, `automation:`, etc.

**Correct:**
```yaml
homeassistant:
  name: Home

rest:
  - resource: http://muadzin.local/api/prayers
    sensor:
      - name: "Prayer Times"
```

**Incorrect (too indented):**
```yaml
homeassistant:
  name: Home
  rest:  # ❌ WRONG - rest should not be under homeassistant
    - resource: http://muadzin.local/api/prayers
```

### Option B: Using packages
If you're using packages:

1. Make sure `configuration.yaml` has:
```yaml
homeassistant:
  packages: !include_dir_named packages
```

2. Create `packages/muadzin.yaml` with the configuration
3. Restart Home Assistant

---

## Step 2: Test with Minimal Configuration

1. **Backup your current configuration.yaml**

2. **Add ONLY this minimal test** (use the direct IP):
```yaml
rest:
  - resource: http://192.168.0.25/api/prayers
    scan_interval: 60
    sensor:
      - name: "Prayer Test"
        value_template: "{{ value_json.next_prayer_name }}"
```

3. **Restart Home Assistant** (Settings → System → Restart)

4. **Check if the sensor appears**:
   - Go to **Developer Tools** → **States**
   - Search for: `prayer`
   - You should see: `sensor.prayer_test`

5. **If it works**: The minimal config is correct. The issue is in the full configuration.
6. **If it doesn't work**: See Step 3 below.

---

## Step 3: Check Home Assistant Logs

1. Go to **Settings** → **System** → **Logs**
2. Look for errors containing:
   - `rest`
   - `muadzin`
   - `prayer`
   - `192.168.0.25`

### Common Error Messages:

#### Error: "Invalid config for [rest]"
**Cause**: YAML syntax error (indentation, missing colons, etc.)

**Fix**:
- Use a YAML validator: https://www.yamllint.com/
- Check indentation (use spaces, not tabs)
- Make sure all colons have a space after them

#### Error: "Unable to fetch data from http://muadzin.local"
**Cause**: Home Assistant can't reach the device

**Fix**:
- Use the IP address instead: `http://192.168.0.25/api/prayers`
- Make sure Home Assistant and Muadzin are on the same network
- Test from Home Assistant machine: `curl http://192.168.0.25/api/prayers`

#### Error: "Template error"
**Cause**: The API response format doesn't match the template

**Fix**: See Step 4 below

---

## Step 4: Verify API Response Format

Run this from your machine:
```bash
curl http://192.168.0.25/api/prayers
```

**Expected response:**
```json
{
  "next_prayer_name": "dhuhr",
  "current_prayer_name": "sunrise",
  "azan_playing": false,
  "prayers": [...],
  "time_to_next_azan_minutes": 241
}
```

If the response is different, the templates need to be updated.

---

## Step 5: Check Entity Names

The sensors might exist with different names. Check these:

1. Go to **Developer Tools** → **States**
2. Search for each of these:
   - `sensor.prayer_times`
   - `sensor.next_prayer`
   - `sensor.prayer`
   - `muadzin`

3. If you find sensors with different names, use those instead.

---

## Step 6: Force Reload REST Integration

Sometimes Home Assistant caches the configuration:

1. Go to **Developer Tools** → **YAML**
2. Click **"Restart"** (full restart, not just YAML reload)
3. Wait 2-3 minutes for sensors to appear
4. Check **Developer Tools** → **States** again

---

## Step 7: Verify Configuration Syntax

Use the Home Assistant configuration checker:

1. Go to **Developer Tools** → **YAML**
2. Click **"Check Configuration"**
3. Look for errors related to `rest` or templates
4. Fix any errors shown

---

## Step 8: Enable Debug Logging

Add this to `configuration.yaml` to get more details:

```yaml
logger:
  default: info
  logs:
    homeassistant.components.rest: debug
```

Restart and check logs again.

---

## Quick Diagnostic Checklist

- [ ] Configuration added to correct file
- [ ] Configuration at correct indentation level
- [ ] Used direct IP instead of muadzin.local
- [ ] Full restart performed (not just YAML reload)
- [ ] Checked logs for errors
- [ ] API returns data when tested with curl
- [ ] Waited 2-3 minutes after restart
- [ ] Checked Developer Tools → States for sensors

---

## Working Minimal Configuration

If all else fails, start with this absolute minimal setup:

```yaml
# In configuration.yaml (at root level, no indentation)

rest:
  - resource: http://192.168.0.25/api/prayers
    sensor:
      - name: "Muadzin Prayer"
        value_template: "{{ value_json.next_prayer_name }}"
```

This creates a single sensor: `sensor.muadzin_prayer` showing the next prayer name.

Once this works, gradually add more sensors from the full configuration.

---

## Still Not Working?

### Test REST integration directly:

1. Go to **Developer Tools** → **Template**
2. Paste this:
```jinja
{{ states('sensor.prayer_times') }}
```
3. If it shows "unknown" or "unavailable", the sensor exists but has no data
4. If it shows "None", the sensor doesn't exist

### Manual API test from Home Assistant:

1. SSH into Home Assistant (if using Home Assistant OS)
2. Run:
```bash
ha core check
curl http://192.168.0.25/api/prayers
```

### Check network connectivity:

From Home Assistant terminal:
```bash
ping 192.168.0.25
nslookup muadzin.local
```

---

## Common Solutions Summary

| Problem | Solution |
|---------|----------|
| Sensors not appearing | Use direct IP (192.168.0.25) instead of muadzin.local |
| Configuration error | Check YAML indentation (spaces, not tabs) |
| Template error | Verify API response format matches templates |
| Sensor shows "unavailable" | Check scan_interval, wait 60 seconds for first update |
| Sensor shows "unknown" | API is unreachable, check network/firewall |

---

## Need More Help?

1. **Check the API manually**:
   ```bash
   curl http://192.168.0.25/api/prayers
   ```

2. **Share the logs**: Copy relevant errors from Settings → System → Logs

3. **Verify configuration**: Use https://www.yamllint.com/ to check syntax

4. **Check Home Assistant version**: This integration requires HA 2023.1 or newer
