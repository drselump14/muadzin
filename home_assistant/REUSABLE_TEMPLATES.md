# Creating Reusable Card Templates in Home Assistant

There are several ways to make your Muadzin prayer card reusable across multiple dashboards and views.

---

## Option 1: Decluttering Card (RECOMMENDED) ⭐

This is the most flexible method that works with both UI and YAML modes.

### Step 1: Install Decluttering Card

1. Go to **HACS** → **Frontend**
2. Search for **"Decluttering Card"**
3. Click **Install**
4. Restart Home Assistant

### Step 2: Create Template File

Create a file in your config folder: `config/decluttering_templates.yaml`

(The file is already created: `decluttering_templates.yaml`)

### Step 3: Configure Lovelace

Add to your `configuration.yaml`:

```yaml
lovelace:
  mode: yaml
  resources:
    - url: /hacsfiles/decluttering-card/decluttering-card.js
      type: module
```

### Step 4: Include Templates

In your dashboard YAML file (e.g., `ui-lovelace.yaml`), add at the top:

```yaml
decluttering_templates: !include decluttering_templates.yaml

views:
  - title: Home
    cards:
      - type: custom:decluttering-card
        template: muadzin_prayer_card
```

### Step 5: Use Anywhere

Now you can use this in any view:

```yaml
- type: custom:decluttering-card
  template: muadzin_prayer_card
```

---

## Option 2: Custom Button Card Templates

If you're already using Custom Button Card, you can create templates.

### Step 1: Install Custom Button Card

From HACS, install **"Custom Button Card"**

### Step 2: Define Template

In your dashboard configuration:

```yaml
button_card_templates:
  muadzin_card:
    # Your card configuration here
    # (This is more complex and better suited for button-card specific features)
```

---

## Option 3: YAML Anchors (Simple but Limited)

If you're using YAML mode, you can use YAML anchors for reusability.

### In your dashboard YAML:

```yaml
# Define the anchor at the top
decluttering_templates:
  muadzin_prayer_card: &muadzin_prayer_card
    type: custom:mushroom-template-card
    primary: "{{ states('sensor.next_prayer') | title }} - {{ (states('sensor.time_to_next_azan') | int / 60) | int }}:{{ '%02d' | format(states('sensor.time_to_next_azan') | int % 60) }}"
    # ... rest of config

views:
  - title: Home
    cards:
      - <<: *muadzin_prayer_card  # Use the anchor

  - title: Dashboard 2
    cards:
      - <<: *muadzin_prayer_card  # Reuse the same card
```

**Limitation:** This only works within a single YAML file.

---

## Option 4: UI Mode with Manual Copy

If you're using UI mode (not YAML mode):

### Method A: Dashboard-level reuse

1. Create the card once
2. Use the "Duplicate" feature in the card editor
3. Paste across views within the same dashboard

### Method B: Cross-dashboard reuse

1. Go to dashboard in Edit mode
2. Click **⋮** → **"Raw Configuration Editor"**
3. Copy the card YAML
4. Switch to another dashboard
5. Open Raw Configuration Editor
6. Paste the card YAML
7. Save

**Limitation:** Changes must be made manually in each location.

---

## Option 5: Create a Custom View Include (YAML Mode)

Split your views into separate files for better organization.

### Step 1: Enable YAML Mode

In `configuration.yaml`:

```yaml
lovelace:
  mode: yaml
  resources:
    - url: /hacsfiles/mushroom/mushroom.js
      type: module
    - url: /hacsfiles/browser-mod/browser-mod.js
      type: module
```

### Step 2: Create View File

Create `config/lovelace/prayer_view.yaml`:

```yaml
title: Prayer Times
path: prayers
cards:
  - type: custom:mushroom-template-card
    primary: "{{ states('sensor.next_prayer') | title }} - {{ (states('sensor.time_to_next_azan') | int / 60) | int }}:{{ '%02d' | format(states('sensor.time_to_next_azan') | int % 60) }}"
    # ... rest of your card config
```

### Step 3: Include in Main Dashboard

In `ui-lovelace.yaml`:

```yaml
views:
  - !include lovelace/prayer_view.yaml
  - title: Other View
    cards:
      - type: entities
        # ...
```

---

## Comparison

| Method | Ease of Use | Flexibility | UI/YAML Mode | Best For |
|--------|-------------|-------------|--------------|----------|
| **Decluttering Card** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Both | Most users |
| **Button Card Templates** | ⭐⭐ | ⭐⭐⭐⭐ | Both | Button card users |
| **YAML Anchors** | ⭐⭐⭐⭐ | ⭐⭐ | YAML only | Simple reuse |
| **UI Copy/Paste** | ⭐⭐⭐⭐⭐ | ⭐ | UI only | Quick one-offs |
| **View Includes** | ⭐⭐ | ⭐⭐⭐ | YAML only | Organization |

---

## Recommended Setup for Muadzin Card

### Best Choice: Decluttering Card

**Why?**
- Works in both UI and YAML mode
- Centralized template - update once, applies everywhere
- Can pass variables to customize each instance
- Most flexible for future changes

### Quick Start:

1. **Install Decluttering Card** from HACS
2. **Copy** `decluttering_templates.yaml` to your `config/` folder
3. **Add to configuration.yaml**:
   ```yaml
   lovelace:
     mode: yaml
     resources:
       - url: /hacsfiles/decluttering-card/decluttering-card.js
         type: module
   ```
4. **In your dashboard**, add:
   ```yaml
   decluttering_templates: !include decluttering_templates.yaml

   views:
     - title: Home
       cards:
         - type: custom:decluttering-card
           template: muadzin_prayer_card
   ```

5. **Done!** Now use `- type: custom:decluttering-card` anywhere you want the card.

---

## Advanced: Parameterized Templates

You can also make templates accept parameters:

```yaml
# In decluttering_templates.yaml
muadzin_prayer_card_custom:
  default:
    - icon_color: green
    - title: "Prayer Times"
  card:
    type: custom:mushroom-template-card
    icon_color: [[icon_color]]
    # ...

# Usage:
- type: custom:decluttering-card
  template: muadzin_prayer_card_custom
  variables:
    - icon_color: blue
    - title: "Salat Times"
```

This allows you to reuse the same template with different colors or titles!

---

## Need Help?

- **Decluttering Card Docs**: https://github.com/custom-cards/decluttering-card
- **Custom Button Card**: https://github.com/custom-cards/button-card
- **Home Assistant YAML Mode**: https://www.home-assistant.io/lovelace/yaml-mode/
