#!/usr/bin/env sh
# ai-quota-popup.sh — Visual AI Quota & Burn Telemetry HUD popup (Prefix + u)
#
# Thin entry point: `ai-quota --popup` (waymux quota --popup) opens the 75% × 60% popup with
# ai-quota's providers and state. Keys: Enter launch (ai-launch --auto), a models
# (ai-launch --pick), r refresh, u / q / Esc close; set in [quota] of ~/.config/waymux/config.toml.

exec "$HOME/.local/bin/ai-quota" --popup "${1:-$PWD}"
