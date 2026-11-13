# Omarchy Quake Console (AI Console)

Omarchy ships a **Quake console**: a dimmed panel that drops from the top over
whatever workspace you are on. It is the special workspace `special:qconsole`,
separate from the full-screen scratchpad on `Super + S`.

- **First open**: when the console is empty, Omarchy seeds it with the default
  coding agent (`omarchy-agent --pick --prefer-local`). With no default agent
  set, it asks which one to use.
- **Hidden, not closed**: toggling it away keeps its windows running.
- **Layout**: a single window is boxed into a centered panel (2:1, top half of
  the screen); a second window gets the full width back.

Stock definitions (read-only, owned by the `omarchy` package):

- `/usr/share/omarchy/default/hypr/bindings/tiling.lua` — the two keybindings
- `/usr/share/omarchy/default/hypr/qconsole.lua` — seeding, dimming, geometry
- `/usr/share/omarchy/default/hypr/gestures.lua` — the touchpad gesture

## ⚠️ Why the stock keys do not work with these dotfiles

| Stock key | Stock action | What these dotfiles do instead |
| :--- | :--- | :--- |
| `Super + `` ` `` | Toggle the Quake console | `Super + dead_grave` → switch to workspace 0 ([`bindings.lua`](../../hypr/.config/hypr/bindings.lua)) |
| `Super + Shift + `` ` `` | Move window to the console | `Super + Shift + dead_tilde` (or `dead_grave`) → move window to workspace 0 |

Two things collide on the same physical key (`<TLDE>`, keycode 49):

1. [`bindings.lua`](../../hypr/.config/hypr/bindings.lua) `hl.unbind`s
   Omarchy's `SUPER + grave` and `SUPER + SHIFT + grave` and binds workspace 0
   to the `dead_grave` / `dead_tilde` **keysyms**, not to keycode 49: on the
   Apple ISO keyboard the key is `<LSGT>` (keycode 94), and `fixgrave` gives
   both keys the same keysyms. The workspace itself is named `zero`, since
   Hyprland rejects `name:0`; the bar's `fecavmi.workspaces` widget labels it `0`.
2. The [`fixgrave`](../../xkb/.config/xkb/symbols/fixgrave) xkb symbol (loaded by
   `kb_layout = "us(intl)+fixgrave"` in [`input.lua`](../../hypr/.config/hypr/input.lua))
   turns that key into `dead_grave` / `dead_tilde`. Omarchy binds the
   **keysym** `grave`, which that key no longer produces.

Nothing else in these dotfiles touches the console: the gesture, `Super + S`,
`Super + O` and `Super + Shift + <1-9>` keep their stock behavior.

## ✅ Ways to reach the console anyway

### 1. Touchpad gesture (works today, no config)

**Three-finger swipe up** toggles the console. The dotfiles do not override
Omarchy's gestures. (Three-finger swipe down opens the Omarchy menu.)

### 2. Command line / scripts

```bash
# Toggle the console
hyprctl dispatch 'hl.dsp.workspace.toggle_special("qconsole")'

# Send the focused window to the console without following it
hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:qconsole", follow = false })'
```

### 3. Alternative keybindings (optional)

The same key with an extra modifier is free in both Omarchy and these
dotfiles. Following the repo's convention of a home-row `Ctrl` chord
(CapsLock hold via `keyd`) with an `Alt` fallback, add to
[`hypr/.config/hypr/bindings.lua`](../../hypr/.config/hypr/bindings.lua):

```lua
-- Quake console (stock Super + ` is taken by workspace 0)
o.bind("SUPER + CTRL + dead_grave", "Toggle Quake console", hl.dsp.workspace.toggle_special("qconsole"))
o.bind("SUPER + ALT + dead_grave", "Toggle Quake console", hl.dsp.workspace.toggle_special("qconsole"))
o.bind("SUPER + CTRL + SHIFT + dead_tilde", "Move window to Quake console", hl.dsp.window.move({ workspace = "special:qconsole", follow = false }))
o.bind("SUPER + ALT + SHIFT + dead_tilde", "Move window to Quake console", hl.dsp.window.move({ workspace = "special:qconsole", follow = false }))
```

Bind the `dead_grave` / `dead_tilde` keysyms (not `grave` or `code:49`) so it works with `fixgrave` on both `<TLDE>` and the Apple ISO `<LSGT>` key. Validate
with `hyprctl reload && hyprctl configerrors`, and confirm with
`omarchy menu keybindings --print | grep -i quake`.

> **Apple ISO keyboards**: there the `` ` `` key is `<LSGT>` (keycode 94) and
> `<TLDE>` is `§`. Check with `wev` and use `code:94` if needed.

## Related console keys (stock, unchanged)

| Key | Action |
| :--- | :--- |
| `Super + Shift + 1`…`0` | Move a window out of the console to that workspace |
| `Super + T` | Toggle floating (re-centers the panel layout on change) |
| `Super + O` | Pop window out (float & pin) |
| `Super + S` | Full-screen scratchpad (a different special workspace) |

To see the console exactly as Omarchy ships it, use a clean test user created by
[`omarchy-clean`](../../utils/.local/bin/omarchy-clean), which loads no dotfiles.
