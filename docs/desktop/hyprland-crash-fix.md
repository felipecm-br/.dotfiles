# Hyprland Crash Fix (Black Screen / Import Loop)

This document explains the reason behind sudden Hyprland crashes (which resulted in a black screen at login) and how to prevent/resolve the issue if it occurs again after an update or dotfiles reset.

---

## 1. The Problem
The Hyprland theme template file ([`omarchy/.config/omarchy/themed/hyprland.lua.tpl`](../../omarchy/.config/omarchy/themed/hyprland.lua.tpl), formerly `hypr/.config/omarchy/themed-overrides/hyprland.conf.tpl`):

Had a self-referencing `source` line active at the top:
```ini
source = ~/.config/omarchy/current/theme/hyprland.omarchy.conf
```

### What happened in practice:
1. When applying or updating a theme, Omarchy's manager would read this `.tpl` file to generate the final compiled file in `~/.local/state/omarchy/current/theme/` (or `~/.config/omarchy/current/theme/`).
2. Since the template contained the instruction to import the compiled file itself, the generated file ended up **importing itself**.
3. When starting Hyprland, it read this `source` line, tried to import the file, which in turn tried to import itself, generating an **infinite recursion**.
4. This overflowed the stack memory (Stack Overflow), resulting in a **Segmentation Fault (Segfault / Core Dump)**.
5. Because Hyprland crashed instantly, the system was stuck on a black screen and the automatic login service (`omarchy-seamless-login.service`) failed because it hit the restart limit (`start-limit-hit`).

---

## 2. The Solution
The definitive solution is to ensure that the template ([`omarchy/.config/omarchy/themed/hyprland.lua.tpl`](../../omarchy/.config/omarchy/themed/hyprland.lua.tpl)) only defines theme variables (`$activeBorderColor`, `$inactiveBorderColor`) and never sources the generated file itself:

### In the template file (Fixed):
[`omarchy/.config/omarchy/themed/hyprland.lua.tpl`](../../omarchy/.config/omarchy/themed/hyprland.lua.tpl)
```ini
$activeBorderColor = rgba({{ accent_strip }}ee) rgba({{ yellow_strip }}ee) 45deg
$inactiveBorderColor = rgba({{ color8_strip }}aa)
```

---

## 3. How to prevent the issue from returning
Since you manage your dotfiles via Git (worktree in `~/.dotfiles/main`), keep template changes committed in Git:

```bash
# 1. Navigate to the repository folder
cd ~/.dotfiles/main

# 2. Add the template fix
git add omarchy/.config/omarchy/themed/hyprland.lua.tpl

# 3. Commit the changes
git commit -m "fix: remove circular source from hyprland theme template to prevent crashes"

# 4. (Optional) Push to your remote repository
git push
```

If the environment crashes again before you can commit, you can restore the service by running:
```bash
bash ~/restart-hyprland.sh
```
