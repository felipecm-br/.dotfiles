#!/usr/bin/env zsh
# Install battery management tools for Asahi Linux on Apple Silicon (M1/M2/M3).
#
# Sets up:
#   - Omarchy's 80% charge limit (omarchy-battery-charge-limit), kept across
#     reboots by asahi-scripts and omarchy-mac; removes the old
#     battery-charge-threshold service that did the same
#   - sudoers drop-in for passwordless limit writes, and the monthly calibration timer
#
# Only applies on aarch64 (Apple Silicon). On x86_64 it installs tlp instead.

set -euo pipefail

BATTERY_PATH="/sys/class/power_supply/macsmc-battery"
OLD_THRESHOLD_CONF="/etc/battery-charge-threshold.conf"
OLD_THRESHOLD_SERVICE="/etc/systemd/system/battery-charge-threshold.service"
SAVED_LIMIT_FILE="/etc/udev/macsmc-battery.conf"

ARCH="$(uname -m)"

# ── Helper ─────────────────────────────────────────────────────────────────────
_write_system_file() {
  # Usage: _write_system_file <dest_path> <content>
  local dest="$1"
  local content="$2"
  print -P "  %F{blue}→%f Writing %B${dest}%b..."
  echo "$content" | sudo tee "$dest" > /dev/null
}

# ══════════════════════════════════════════════════════════════════════════════
# 2. Charge limit (Apple Silicon only): Omarchy's, not a service of our own
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$ARCH" == "aarch64" ]] && [[ -d "$BATTERY_PATH" ]]; then

  # The old service wrote the same limit at boot. Its ExecStop lifts the limit
  # to 100%, so it is stopped first and the limit is set after.
  migrated=false
  if [[ -f "$OLD_THRESHOLD_SERVICE" ]]; then
    migrated=true
    print -P "  %F{blue}→%f Removing the old battery-charge-threshold service..."
    sudo systemctl disable --now battery-charge-threshold 2>/dev/null || true
    sudo rm -f "$OLD_THRESHOLD_SERVICE" "$OLD_THRESHOLD_CONF"
    sudo systemctl daemon-reload
    print -P "  %F{green}✓%f Old service removed"
  fi

  # Set the limit on a fresh install or right after the migration; a limit the
  # user chose since (even 100%) is left alone.
  if [[ $migrated == true ]] || ! grep -qE '^CHARGE_CONTROL_END_THRESHOLD=[0-9]+$' "$SAVED_LIMIT_FILE" 2>/dev/null; then
    if command -v omarchy-battery-charge-limit &>/dev/null; then
      print -P "  %F{blue}→%f Setting Omarchy's 80%% charge limit..."
      omarchy-battery-charge-limit 80
    else
      print -P "  %F{yellow}⚠%f omarchy-battery-charge-limit not found (omarchy-mac). Skipping the charge limit."
    fi
  else
    print -P "  %F{cyan}✓%f Charge limit already set: %B$(cat "$BATTERY_PATH/charge_control_end_threshold")%%%b"
  fi

elif [[ "$ARCH" != "aarch64" ]]; then
  print -P "  %F{yellow}⚠%f The charge limit is Apple Silicon only (aarch64). Skipping."
else
  print -P "  %F{yellow}⚠%f Battery sysfs path %B${BATTERY_PATH}%b not found. Skipping the charge limit."
  print -P "    This is expected if you are not on Asahi Linux."
fi

# ══════════════════════════════════════════════════════════════════════════════
# 3. Sudoers drop-in — passwordless sysfs threshold writes
# ══════════════════════════════════════════════════════════════════════════════
# Required by battery-calibrate-auto running as a systemd user service (no TTY).
SUDOERS_SRC="${0:A:h}/../../../battery/etc/sudoers.d/10-battery-threshold"
SUDOERS_DEST="/etc/sudoers.d/10-battery-threshold"

if ! sudo cmp -s "$SUDOERS_SRC" "$SUDOERS_DEST" 2>/dev/null; then
  print -P "  %F{blue}→%f Installing sudoers drop-in for battery threshold writes..."
  # visudo -c validates syntax before writing; fail loudly if the file is broken
  if sudo visudo -c -f "$SUDOERS_SRC" &>/dev/null; then
    sudo install -m 0440 -o root -g root "$SUDOERS_SRC" "$SUDOERS_DEST"
    print -P "  %F{green}✓%f Sudoers drop-in installed at %B${SUDOERS_DEST}%b"
  else
    print -P "  %F{red}✗%f Sudoers syntax check failed — skipping install"
  fi
else
  print -P "  %F{cyan}✓%f Sudoers drop-in up to date"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 4. Monthly calibration systemd user timer
# ══════════════════════════════════════════════════════════════════════════════
# The timer calls battery-calibrate-auto on the 1st of each month.
# Persistent=true means it fires at next boot if the machine was off on the due date.
if ! systemctl --user is-enabled battery-calibrate.timer &>/dev/null; then
  print -P "  %F{blue}→%f Enabling battery-calibrate user timer..."
  systemctl --user daemon-reload
  systemctl --user enable --now battery-calibrate.timer
  print -P "  %F{green}✓%f battery-calibrate.timer enabled"
else
  print -P "  %F{cyan}✓%f battery-calibrate.timer already enabled"
fi

print -P "  %F{green}  ✓%f Battery management setup complete"
