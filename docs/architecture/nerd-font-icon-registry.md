# Nerd Font Icon Registry

Every glyph that stands for a **program, agent, or agent state** comes from one place: the
waymux icon registry. To change an icon or add a new one, edit one line and every surface
picks it up: tmux window names, the Cockpit, alert bells, close modals, the AI updater, and
notifications.

## Source of truth

| What | Where |
| --- | --- |
| Program/agent glyphs (`claude`, `devin`, `yazi`, `zsh`, ...) | `[icons]` in [`waymux/.config/waymux/config.toml`](../../waymux/.config/waymux/config.toml) |
| Agent-state glyphs (`idle`, `busy`, `question`, `permission`, `stalled`, `error`) | `[theme.states.<state>].icon` in the same file |
| Built-in defaults (used when a key is missing) | `src/icons.rs` in the waymux repository |

`config.toml` is hand-maintained and has no Omarchy template: theme switches only restart
waymux, they never rewrite the file.

Special keys:

- `agent` is the generic glyph for an agent that has no entry of its own.
- `ai` is the glyph for the AI tooling as a whole (updater header, sound notifications).
- `awaiting_input` and `hanging` are aliases of `question` and `stalled`, so they always share a glyph.

## Reading the registry

| Consumer | How it reads |
| --- | --- |
| waymux (hook window rename, Cockpit rows, tmux/waybar state badges, bell alerts) | Natively, via `icons::Registry` |
| tmux-nerd-font-window-name plugin | [`nerd-font-icons-sync.sh`](../../tmux/.config/tmux/nerd-font-icons-sync.sh) joins the base [`tmux-nerd-font-window-name.yml`](../../tmux/.config/tmux/tmux-nerd-font-window-name.yml) with `waymux icons --format tmux` into `~/.cache/tmux/tmux-nerd-font-window-name.yml`, and points the plugin there. It runs from `tmux.conf` before TPM. |
| `update-ai-workflow`, `window-picker-items.sh` | `eval "$(waymux icons --format sh)"`, one call per run, which gives `ICON_<KEY>` and `ICON_STATE_<STATE>` (`ai-memory` becomes `ICON_AI_MEMORY`) |
| `close-window.sh`, `close-session.sh`, `agy`, `agyy`, the Antigravity hooks, `ai-sound-*`, zsh helpers | `waymux icon <name>` / `waymux icon --state <state>` (exits 1 when the key is unknown) |

## CLI

```bash
waymux icon devin                 # one program/agent glyph
waymux icon --state awaiting_input   # one state glyph (aliases resolved)
waymux icons                      # TSV: kind, key, glyph
waymux icons --format sh          # ICON_* assignments for eval
waymux icons --format tmux        # the plugin's `icons:` YAML section
```

## Changing or adding an icon

1. Edit `[icons]` (or `[theme.states.*]`) in `config.toml`.
2. Reload tmux (`prefix r`), or run `~/.config/tmux/nerd-font-icons-sync.sh`, to rebuild the
   plugin config. Everything else reads the registry on every call.
3. Windows that are already open keep their name until the next rename (new command, or the
   agent's next lifecycle hook).

## What stays out of the registry

Picker-local UI chrome is not a name-to-glyph mapping, so it stays next to its UI: popup frame
badges, menu entries, Waymaker prompts such as the sounds preset, and the Quickshell workspace
pills (`Workspaces.qml`), which map Hyprland window classes, not processes. The legacy bash
Cockpit fallback in `cockpit-picker-items.sh` keeps its own glyphs because it only runs when
waymux is not installed.
