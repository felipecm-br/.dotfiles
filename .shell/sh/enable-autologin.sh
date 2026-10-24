#!/usr/bin/env bash
set -e

TARGET_USER="${1:-$USER}"

echo "Configuring SDDM autologin for: $TARGET_USER"
sudo mkdir -p /etc/sddm.conf.d
printf "[Autologin]\nUser=%s\nSession=hyprland\nRelogin=false\n" "$TARGET_USER" | sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null
echo "✓ Hyprland autologin configured successfully!"
cat /etc/sddm.conf.d/autologin.conf
