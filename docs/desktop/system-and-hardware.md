# Desktop, Displays, Terminal & Hardware Management

System-level behaviors, Wayland display hotplugging, Ghostty terminal optimizations, and hardware power profiles.

---

## 1. Automatic Monitor Management via Kanshi

Display profiles and hotplug events are automatically handled by [`kanshi`](https://github.com/emersion/kanshi), a Wayland monitor daemon.

### How it Works

- **Autostart**: `kanshi` is launched on session start via [`hypr/.config/hypr/autostart.lua`](../../hypr/.config/hypr/autostart.lua):
  ```ini
  exec-once = kanshi
  ```
- **Hotplug Detection**: `kanshi` listens to Wayland output events. When an external monitor (or Ultrawide display) is plugged in or disconnected, it automatically applies matching display profiles without restarting Hyprland.
- **Profile Layouts**: Configured in `~/.config/kanshi/config`:

  ```kanshi
  # External Ultrawide connected: disable laptop screen, set HDMI resolution & reserved space
  profile {
      output "eDP-1" disable
      output "HDMI-A-1" mode 2560x1080 position 0,0
      exec hyprctl keyword monitor "HDMI-A-1,addreserved,-10,0,0,0"
  }

  # Standalone laptop: enable internal display
  profile {
      output "eDP-1" enable
  }
  ```

---

## 2. Ghostty Terminal Enhancements

Configurations in [`ghostty/.config/ghostty/config`](../../ghostty/.config/ghostty/config) provide several advanced terminal features:

- **CSI u Key Escapes**: Maps `Ctrl+1` through `Ctrl+9` and `Ctrl+~` to explicit CSI u escape codes (e.g. `\x1b[49;5u`), ensuring terminal multiplexers like `tmux` reliably capture window navigation keybindings.
- **Hyprland Performance (`epoll`)**: Sets `async-backend = epoll` to eliminate event loop latency under Hyprland.
- **Custom Shaders**: Includes GPU GLSL shader effects (`cursor_frozen.glsl` / `cursor_blaze.glsl`) for custom visual cursor rendering.

---

## 3. Battery Management & CPU Power Profiles

Hardware battery health and CPU energy management scripts shipped in the [`battery`](../../battery) stow package (`battery/.local/bin/`):

- **Charge limit**: Omarchy's own limit, `omarchy-battery-charge-limit 80` (from `omarchy-mac`, shown in the bar's power panel as "Charge limit"): the SMC stops charging at 80% and resumes at 75%, so plugged in the Mac runs from the charger. No service of ours keeps it: asahi-scripts saves every change of `charge_control_end_threshold` to `/etc/udev/macsmc-battery.conf`, and its udev rule and omarchy-mac's `battery-charge-limit-restore` write it back at boot. [`.shell/install/packages/battery.zsh`](../../.shell/install/packages/battery.zsh) sets it and removes the old `battery-charge-threshold` service, which did the same job.
- **Limitation**: The limit only holds while Linux runs. A Mac shut down on the charger charges to 100%; suspend instead, or shut down unplugged.
- **Bar label**: The bar uses `fecavmi.power`, a clone of Omarchy's power widget ([`omarchy/.config/omarchy/plugins/fecavmi.power`](../../omarchy/.config/omarchy/plugins/fecavmi.power)) with one change in `Model.js`: a battery UPower reports as fully charged reads "Fully charged". The stock widget wants exactly 100%, and the Apple gauge stops at about 99.96%, so on the charger it showed "Charging" at 0 W.
- **`battery-threshold`**: `show`, `set <N>` (80 and 100 go through Omarchy's command, other values straight to sysfs), `reset` (100%), and `calibrate`. The driver derives the resume point from the limit, so there is no separate start threshold.
- **CPU Performance Toggle (`perf-toggle`)**: Switches CPU energy-performance hints between `performance`, `balanced`, and `power-saver` modes on the fly.
- **Waybar Status (`perf-waybar`)**: Integrates live power state and battery condition into the Waybar status bar.
