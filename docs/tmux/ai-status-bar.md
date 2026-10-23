# Per-Pane AI Agent Status in Tmux Status Bar

The tmux status bar displays real-time, dynamic state for AI agents (Antigravity / Claude Code / Codex / Muse / OpenCode) running in each pane.
State is pushed into tmux options `@ai_agent_state`, `@ai_agent_state_color`, `@ai_agent_state_raw`, `@ai_agent_title`, and `@ai_agent_bell` by the centralized `waymux` daemon (`127.0.0.1:4040`) and client hooks (`tmux-hook.mjs` / `hooker.ts`).

---

## 1. Dynamic Pill Layout & Color States (`window-status-current-format`)

The active window tab is rendered as a rounded pill (`` ... ``) whose background color changes dynamically based on the AI agent state (`@ai_agent_state_color`).

State colors are **semantic constants**, not theme slots: `waymux` picks them from a built-in palette for the theme's mode (`mode` in Omarchy's `colors.toml`, else background luminance), shared by the status bar, Waybar and the Cockpit. Theme slots collapse on many themes (`lumon` maps every slot to blue; `tokyo-night` gives permission and stalled the same orange). Values are dark / light:

| State | Glyph | Dark | Light |
| :--- | :---: | :---: | :---: |
| `busy` / `working` (animated spinner `⠋`) | `󰑮` | `#89b4fa` blue | `#2563eb` |
| `question` / `awaiting_input` | `󱜻` | `#f9e2af` gold | `#7c6a00` |
| `permission` | `󱅭` | `#ff9e57` orange | `#c2410c` |
| `stalled` | `󱥁` | `#f5c2e7` pink | `#a21caf` |
| `error` | `󰨄` | `#ff6b7a` red | `#be123c` |
| `idle` (done, waiting for your next prompt) | `󱥂` | `#8aa4b8` slate | `#4f6b5f` |

A new, resumed or cleared session starts `idle`: `SessionStart` only renames the window and sets the title, and the spinner starts on `UserPromptSubmit`. A `compact` `SessionStart` (which can fire mid-turn) leaves the state untouched.

The window icon comes from the agent binary running in the pane (`pane_current_command`); the agent named in the hook command (`waymux hook tmux <Event> claude`) only applies when the pane runs no known agent binary (e.g. a `node`-wrapped CLI). Devin imports `~/.claude/settings.json`, so every Claude hook also fires inside Devin windows alongside the ones in [`devin/.config/devin/config.json`](../../devin/.config/devin/config.json). The duplicates are harmless: sounds, bells and telemetry fire only on state transitions. Any hook added to the Claude settings also runs in Devin.

The Cockpit adds `review` (`󰈈`, done but not reviewed): `#7ee0b5` dark / `#166534` light. Windows without an agent use `@CURRENT_COLOR`. Every pair stays apart by at least 10.8 CIEDE2000 on the dark palette, including simulated deuteranopia and protanopia; on the light palette, question and permission converge for red-green color deficiency, so the glyph carries that difference. All values reach 4.5:1 contrast on every built-in Omarchy background. To pin a color, set `color = "#rrggbb"` for that state in [`config.toml`](../../waymux/.config/waymux/config.toml); an empty `color` means the built-in palette.

Inside the active filled pill, the window title `#W` and state icon `@ai_agent_state` are forced to high-contrast dark text (`fg=#{@SESSION_ACTIVE_FG}`) for clean legibility on top of filled backgrounds.

---

## 2. Background Tab Notifications (`window-status-format`)

For inactive background tabs, `@ai_agent_state` is rendered in `#[fg=#{@ai_agent_state_color}]`. Status icons light up in their state colors in the background so you can monitor agent progress and input requests across windows at a glance.

---

## 3. Orthogonal Tmux Options Pushed by `waymux` & Agent Hooks

- `@ai_agent_state`: Pure icon or animated spinner frame string without embedded ANSI color tags (e.g. `⠋`, `󱜻`, `󱅭`, `󰨄`).
- `@ai_agent_state_color`: Hex color resolved by `waymux`: the state's `color` override from `config.toml` when set, else the built-in semantic palette above (e.g. `#89b4fa`, `#ff9e57`).
- `@ai_agent_title`: Clean active session title or initial prompt (e.g. `Fix memory leak in parser`), rendered in the Cockpit & Window Pickers (`Prefix + Space` / [`cockpit-picker.sh`](../../tmux/.config/tmux/cockpit-picker.sh) and [`window-picker.sh`](../../tmux/.config/tmux/window-picker.sh)) matching the window item color and indexed for instant Waymaker fuzzy search.

---

## 4. In-Situ Vimium-Style Window Hints (`Prefix + f`)

To navigate tabs with zero screen occlusion and sub-100ms latency without opening modal pickers, `Prefix + f` activates the `window_hints` keytable:

- **Visual State**: The session pill turns into `󰌌 #S` (`@PREFIX_COLOR`), inactive tab indices (`#I:`) transform into high-contrast Powerline half-round pills (`a`, `s`, `d`...), and the active window displays its bracketed hint (`[s]`).
- **Home-Row Mapping**:
  - Windows 0 to 3: `a`, `s`, `d`, `f` (Left hand Home Row)
  - Windows 4 to 7: `j`, `k`, `l`, `;` (Right hand Home Row)
  - Windows 8 & 9: `g`, `h` (Inner reaches)
  - Fallback: Direct numbers `0..9` also work within hint mode.
- **Single-Key & Cascading Exit**: Pressing any assigned hint key jumps immediately to that window and restores the root keytable ($T_{\text{exec}} \approx 380\text{ ms}$, $T_R = 0\text{ ms}$). Pressing `CapsLock` (emitting `Esc`) or any unmapped key cancels without switching.

See [`tmux/.config/tmux/tmux.conf`](../../tmux/.config/tmux/tmux.conf), [`waymux/.config/waymux/config.toml`](../../waymux/.config/waymux/config.toml), and [`popup-isolation-and-debounce.md`](popup-isolation-and-debounce.md) for debounce, popup isolation, and option wiring details.
