# Eyelash Sofle: Home-Row Chord Guide

How to type every hot-path shortcut in these dotfiles on the [Eyelash Sofle](eyelash-sofle-keyboard.md), which chords already sit well on the home row, and which small keymap changes would make the rest of them better.

The chord inventory comes from the configured bindings ([Workflow Keybindings Matrix](../architecture/workflow-keybindings-matrix.md), `tmux.conf`, the zsh widgets and the Omarchy / personal Hyprland bindings). It is not keystroke telemetry. Timings are KLM-GOMS estimates using the [manifesto's](../architecture/terminal-ergonomics-and-ux-manifesto.md) constants ($T_K = 120\text{ ms}$ for a home-row tap), not measurements.

---

## 🦴 1. Diagnosis: Where the Modifiers Live

```
 LEFT HAND                                               RIGHT HAND
╭─────┬─────┬─────┬─────┬─────┬─────╮           ╭─────┬─────┬─────┬─────┬─────┬─────╮
│  `  │  1  │  2  │  3  │  4  │  5  │   (joy)   │  6  │  7  │  8  │  9  │  0  │  -  │
├─────┼─────┼─────┼─────┼─────┼─────┤           ├─────┼─────┼─────┼─────┼─────┼─────┤
│Tab  │  Q  │  W  │  E  │  R  │  T  │           │  Y  │  U  │  I  │  O  │  P  │  \  │
│▸Alt │     │     │     │     │     │           │     │     │     │     │     │     │
├─────┼─────┼─────┼─────┼─────┼─────┤           ├─────┼─────┼─────┼─────┼─────┼─────┤
│Esc  │  A  │  S  │  D  │  F  │  G  │           │  H  │  J  │  K  │  L  │  ;  │  '  │
│▸Ctrl│     │     │     │     │     │           │     │     │     │     │     │     │
├─────┼─────┼─────┼─────┼─────┼─────┤           ├─────┼─────┼─────┼─────┼─────┼─────┤
│Shift│  Z  │  X  │  C  │  V  │  B  │  (knob)   │  N  │  M  │  ,  │  .  │  /  │Shift│
╰─────┴─────┼─────┼─────┼─────┼─────╯           ╰─────┼─────┼─────┼─────┼─────┴─────╯
            │PrSc │ GUI │ Alt │                       │  [  │  ]  │ ▸3  │
            ╰─────┴─────┴─────╯                       ╰─────┴─────┴─────╯
         left thumbs: BkSp · Space▸TWO      right thumbs: Return · Space
```

`▸` marks the hold action of a dual-role key. `▸3` is the momentary key for layer THREE.

| Modifier | Position on the Sofle | Finger | Homing cost |
| :--- | :--- | :--- | :--- |
| `Ctrl` | Hold `Esc`, left home row, outer column | Left pinky | $H = 0$: the pinky is already there |
| `Esc` | Tap the same key | Left pinky | $H = 0$ |
| `Alt` | Hold `Tab` (one row up) or the bottom row under `V` | Left pinky / index | Small reach. Rare by design |
| `Shift` | Outer bottom corners on both halves | Pinkies | Diagonal pinky stretch on every capital |
| `Super` (`GUI`) | Bottom row under `C` | Left middle finger, curled two rows down | **Hand shift**, about $+150\text{ ms}$ per chord |
| Layer TWO | Hold left thumb `Space` | Left thumb | $H = 0$ |
| `Enter` | Right inner thumb (also the joystick press) | Right thumb | $H = 0$, unlike a pinky `Enter` on a laptop |

**Key finding: Ctrl, Alt and Super exist only on the left half.** The right half has `Shift` and nothing else. That makes `Ctrl` or `Super` plus a **right-hand** key a clean two-hand chord, while `Ctrl` or `Super` plus a **left-hand** key always ties up a single hand.

### What makes a chord good on this board

1. **Cross-hand beats same-hand.** One hand holds the modifier, the other taps. No tendon competes with another in the same hand.
2. **Same-hand is fine as an inward roll on the home or top row.** Pinky `Ctrl` rolling toward the index (`Ctrl+G`, `Ctrl+F`, `Ctrl+R`, `Ctrl+T`) is natural flexion.
3. **Same-hand to the number row is bad.** Pinky `Ctrl` held while another finger reaches `1`–`5` forces a spread stretch with the wrist lifted.
4. **Thumb plus finger on the same hand is fine.** Thumbs move independently of the finger columns.
5. **Never chord with the left thumb `Space` while holding a modifier you mean to keep.** It is a Layer-Tap: a slow press turns into layer TWO.

---

## ⌨️ 2. Your Hot-Path Chords on the Sofle Today

| Chord | What it does | How to press it on the Sofle | Pattern | Est. $T$ | Verdict |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `Esc` | Unwind / normal mode | Tap left pinky home key | Single tap | 120 ms | ✅ |
| `Enter` / `j + Enter` | Confirm / jump home | Right thumb (`j` index, then thumb) | Same-hand roll, index to thumb | 100 ms | ✅ Sacred reflex preserved |
| `Tab` (empty prompt) | Waymaker jump | Tap left pinky top-row key | Single tap | 120 ms | ✅ |
| `Ctrl+Space` | **Tmux prefix** | Hold pinky `Esc/Ctrl` + tap **right** thumb `Space` | Cross-hand | 130 ms | ✅ (use the right thumb, not the left one) |
| `Prefix + h` / `l` / `Space` / `f` / `s` / `i` / `I` / `o` / `m` | Tmux navigation, cockpit, hints, sessions, agents | Prefix, release, tap the letter | Mostly right hand after a left-hand prefix | 250 ms | ✅ Alternating hands |
| `Ctrl+G` | Lazygitrs popup / dual-diff toggle | Pinky `Ctrl` + left index `G` | Same-hand inward roll | 130 ms | ✅ |
| `Ctrl+F` / `Ctrl+R` / `Ctrl+T` / `Ctrl+S` | Jump widget, atuin, IntelliShell, lazygitrs log | Pinky `Ctrl` + left `F` / `R` / `T` / `S` | Same-hand inward roll | 130 ms | ✅ |
| `Ctrl+K` / `Ctrl+J` / `Ctrl+N` / `Ctrl+U` / `Ctrl+L` / `Ctrl+H` | History search, completion, Waymaker ancestor jump and traversal | Pinky `Ctrl` + right-hand letter | Cross-hand | 130 ms | ✅ Best possible |
| `Ctrl+Backspace` | Delete previous word | Pinky `Ctrl` + left thumb `BkSp` | Same hand, pinky + thumb | 130 ms | ✅ |
| `Ctrl+Shift+G` / `T` / `I` | AWT popup, reopen tab, AI triage | Left pinky `Ctrl` + right pinky `Shift` + left-hand letter (one pinky cannot hold both) | Three keys, both hands | 180 ms | ⚠️ Works, but needs the right pinky stretch to `Shift` |
| `Ctrl+1` … `Ctrl+5` | Tmux window 1–5 | Pinky `Ctrl` + left number row | Same-hand stretch to the number row | 200 ms | ⚠️ Spread stretch |
| `Ctrl+6` … `Ctrl+9` | Tmux window 6–9 | Pinky `Ctrl` + right number row | Cross-hand | 140 ms | ✅ |
| `Super+Return` | Terminal | Middle finger `GUI` (bottom row) + right thumb | Cross-hand after a hand shift | 270 ms | ⚠️ `GUI` reach |
| `Super+Space` | Omarchy menu | `GUI` + **right** thumb `Space` | Cross-hand after a hand shift | 270 ms | ⚠️ `GUI` reach |
| `Super+W` / `Super+T` / `Super+F` / `Super+S` | Close, float, fullscreen, scratchpad | `GUI` + left-hand letter | Same hand: curled middle finger plus a top/home-row letter | 300 ms | ❌ Claw grip |
| `Super+J` / `Super+L` / `Super+K` / `Super+O` | Split, layout, keybindings, pop out | `GUI` + right-hand letter | Cross-hand after a hand shift | 270 ms | ⚠️ `GUI` reach |
| `Super+1` … `Super+9` | Workspaces | `GUI` + number row | 1–5 same-hand claw, 6–9 cross-hand | 300 / 270 ms | ❌ / ⚠️ |
| `Super+←↓↑→` | Focus window | `GUI` + left thumb TWO + right `H J K L` | Three keys, both hands, all near home | 300 ms | ⚠️ Works without the joystick |
| `Super+Shift+…` | App launchers | `GUI` + right `Shift` + letter | Three keys | 320 ms | ⚠️ Rare, acceptable |
| `Alt+…` | (avoided by design) | Hold `Tab` | Pinky top row | 140 ms | ✅ Available, rarely needed |

**Summary:** everything built on `Ctrl` is already in very good shape. The weak spot is **`Super`**: every Hyprland chord starts with a curled middle finger two rows below home. The second weak spot is **`Ctrl` + left number row** for tmux windows 1–5.

---

## 🎯 3. Recommended Chords and Habits (No Firmware Change)

These cost nothing: they only change *which* physical key you press.

| Instead of | Prefer | Why |
| :--- | :--- | :--- |
| `Ctrl` + left thumb `Space` for the tmux prefix | `Ctrl` + **right** thumb `Space` | Cross-hand, and no risk of activating layer TWO |
| Reaching for `Enter` with the pinky | Right thumb `Return` | $H = 0$; `j + Enter` becomes an index-to-thumb roll |
| The joystick for arrows while typing | Hold left thumb (TWO) + `H J K L` | Hands never leave home; the joystick is for one-handed browsing |
| `Ctrl+Arrow` with the joystick | Pinky `Ctrl` + left thumb (TWO) + `H` / `L` | Word jumps from home position |
| `F1`–`F12` on the number row | Left thumb (TWO) + number row | They live on layer TWO; no top-row hunt |
| `Ctrl+1`…`Ctrl+5` | `Prefix + h` / `l`, `Prefix + Tab` (MRU), or the cockpit (`Prefix + Space`) | Avoids the same-hand number stretch for the most common moves |
| `Super+1`…`Super+5` with the claw grip | `Super+Tab` / `Super+Shift+Tab` for neighbouring workspaces, or apply change 1 below | `Tab` is a pinky key, so the hand opens instead of clawing until `Super` moves to a thumb |
| `Shift` held for a whole capital | Tap `Shift` then the letter, if change 4 below is applied | Shorter pinky load |

---

## 🛠️ 4. Recommended Keymap Changes, Ranked

All changes in this table can be made live in ZMK Studio (no flashing). Each is reversible. After applying any of them, run `scripts/zmk-keymap/run.sh` and update this page and [the keyboard page](eyelash-sofle-keyboard.md) in the same commit.

| Rank | Change | Positions | Fixes | Trade-off |
| :-: | :--- | :--- | :--- | :--- |
| 1 | Right inner thumb: `Return` → **Mod-Tap `LGUI` / `Return`** (tap = Return, hold = Super) | ONE `59` | Every `Super` chord becomes thumb + any key: `Super+W` 300 → 150 ms, `Super+1..5` claw → cross-hand, `Super+Space` with the left thumb tap | A slow `Return` tap could register as Super. `Return` stays available on the joystick press |
| 2 | Right outer home key: `'` → **Mod-Tap `RCtrl` / `'`** (mirror of the left `Esc/Ctrl`) | ONE `38` | `Ctrl+1..5`, `Ctrl+Shift+G/T/I`, `Ctrl+A/S/D/F/G` all become cross-hand | Apostrophes typed fast in prose may misfire; needs the hold-tap tuning from the keyboard page |
| 3 | Left bottom-row `GUI` → `LCtrl` once change 1 is in place | ONE `54` | Frees a dead key; gives a backup `Ctrl` for the rare mouse-plus-Ctrl case | None meaningful |
| 4 | Outer `Shift` keys → **Sticky Key `LShift`** | ONE `39`, `51` | Tap-then-letter capitals; still a normal Shift when held | One more concept to learn |
| 5 | Bind **`Caps Word`** on layer THREE, e.g. left home `A` position | THREE `27` | `SCREAMING_CASE` constants and env vars without holding Shift | None |

Changes 1 and 2 together give the board a **symmetric modifier set**: `Ctrl` under both pinkies, `Super` under the right thumb, layer TWO under the left thumb. Every chord in section 2 then becomes either a cross-hand chord or a thumb plus finger chord, which brings the remaining ⚠️ and ❌ rows down to about 130–150 ms.

### Not recommended

- **Home-row mods everywhere** (`A S D F` as `GUI Alt Ctrl Shift`): the pinky `Esc/Ctrl` already covers `Ctrl` at $H = 0$. Adding home-row mods buys little here and adds timing misfires during fast typing.
- **Moving `Esc` off the pinky**: it is the most-used key in this setup and already costs one tap. Zero-churn rule.
- **Any `Alt`-based chord** for new bindings: keep `Alt` on `Tab` as a fallback only, as the [manifesto](../architecture/terminal-ergonomics-and-ux-manifesto.md) prescribes.

---

## 🔗 Related

- [Eyelash Sofle Keyboard](eyelash-sofle-keyboard.md): full keymap, PDF, ZMK Studio runbook and firmware-level tips (hold-tap tuning, Bluetooth fixes).
- [Workflow Keybindings Matrix](../architecture/workflow-keybindings-matrix.md): the canonical list of the chords mapped above.
- [Universal Keyboard Ergonomics & Dual-Profile Architecture](../architecture/universal-keyboard-ergonomics-and-profiles.md): the `keyd` CapsLock contract the Sofle reproduces in firmware.
