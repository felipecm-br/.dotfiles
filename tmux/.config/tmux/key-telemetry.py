#!/usr/bin/env python3
"""
key-telemetry.py — which shortcuts you use, which you never touch, and where a shorter path
existed.

  install          wrap every prefix and root tmux binding (clicks included, scroll and drag
                   left alone) so each press is logged
                   (run from tmux.conf; `set -g @key_telemetry off` disables it)
  report [--days N] usage, unused bindings and faster-path suggestions (default 14 days)

Presses land in $XDG_STATE_HOME/flow/keys.tsv through `waymux keylog`; the Cockpit logs its
own keys the same way. Columns: epoch, context, key, row state, row target, origin window.
"""

import argparse
import collections
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

STATE_HOME = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
KEYS_TSV = os.path.join(STATE_HOME, "flow", "keys.tsv")
TMUX_CONF = os.path.expanduser("~/.config/tmux/tmux.conf")
# Same place as waymux's presets::runtime_dir().
_RUNTIME = os.environ.get("XDG_RUNTIME_DIR")
COCKPIT_TOML = os.path.join(
    os.path.join(_RUNTIME, "waymux") if _RUNTIME else f"/tmp/waymux-{os.getuid()}", "cockpit-picker.toml"
)

# States where the agent waits on you: Prefix + I reaches them without the Cockpit.
WAITING = {"permission", "question", "awaiting_input", "error", "stalled", "hanging", "review"}
GIT_KEYS = {"g", "G", "gg", "ctrl-g", "p", "P", "ctrl-p"}
BIND_RE = re.compile(r"^bind-key\s+((?:-\w\s+)*)-T\s+(\S+)\s+(\S+)\s+(.*)$")
MOUSE_RE = re.compile(r"Mouse|Wheel|DoubleClick|TripleClick")
# Scroll ticks and drag motion fire tens of events a second and carry no habit worth a tip.
SKIP_RE = re.compile(r"Wheel|Drag")
# Where a click landed relative to the focus before it: the clicked pane is the focused one
# (`same`), another pane of the current window (`pane`), or another window (`window`).
CLICK_STATE = "#{?window_active,#{?pane_active,same,pane},window}"


def tmux(*args: str) -> str:
    try:
        return subprocess.run(["tmux", *args], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def key_label(token: str) -> str:
    """The key as tmux prints it, made safe for a single-quoted shell word."""
    return token.replace("\\", "").replace("'", "quote").replace('"', "dquote")


# ---------- install ----------


def binding_notes(listing: str) -> Dict[str, str]:
    """Key -> note from `list-keys -N -P ''`: rebinding without -N would drop it from the
    `list-keys -N` reference."""
    notes = {}
    for line in listing.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) == 2:
            notes[key_label(parts[0])] = parts[1].strip()
    return notes


def wrapped_bindings(listing: str, waymux: str, notes: Optional[Dict[str, str]] = None) -> List[str]:
    """`bind-key` lines that log the press before running the original command, keeping each
    key's note. `waymux` is an absolute path: run-shell uses the tmux server's PATH, which may
    lack ~/.local/bin."""
    notes = notes or {}
    out = []
    for line in listing.splitlines():
        m = BIND_RE.match(line.strip())
        if not m or "keylog" in line:
            continue
        flags, table, key, command = m.groups()
        if SKIP_RE.search(key):
            continue
        # `-t =` is the mouse target; use it only where the original command does, since a
        # failing command in the list would stop the click itself from running.
        mouse_target = bool(MOUSE_RE.search(key)) and "-t =" in command
        target_flag, state = ("-t = ", CLICK_STATE) if mouse_target else ("", "")
        log = (
            f"run-shell -b {target_flag}\"{waymux} keylog tmux '{table}:{key_label(key)}' '{state}' "
            f"'#{{session_name}}:#{{window_index}}'\""
        )
        note = notes.get(key_label(key), "").replace("'", "’")
        note_flag = f"-N '{note}' " if note else ""
        out.append(f"bind-key {flags}{note_flag}-T {table} {key} {log} \\; {command}")
    return out


def supports_keylog(waymux: str) -> bool:
    """An older waymux exits 2 on `keylog`, and tmux would flash that error on every press."""
    try:
        return subprocess.run([waymux, "keylog"], capture_output=True, timeout=5).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def install() -> int:
    if tmux("show-options", "-gqv", "@key_telemetry").strip() == "off":
        return 0
    waymux = shutil.which("waymux")
    if not waymux or not supports_keylog(waymux):
        return 0
    lines: List[str] = []
    for table in ("prefix", "root"):
        notes = binding_notes(tmux("list-keys", "-N", "-P", "", "-T", table))
        lines += wrapped_bindings(tmux("list-keys", "-T", table), waymux, notes)
    if not lines:
        return 0
    with tempfile.NamedTemporaryFile("w", suffix=".tmux", delete=False) as f:
        f.write("\n".join(lines) + "\n")
        path = f.name
    try:
        tmux("source-file", path)
    finally:
        os.unlink(path)
    return 0


# ---------- report ----------


class Press(NamedTuple):
    ts: int
    ctx: str
    key: str
    state: str
    target: str
    origin: str


def load_presses(since: int) -> List[Press]:
    presses = []
    try:
        with open(KEYS_TSV, encoding="utf-8", errors="ignore") as f:
            for line in f:
                p = line.rstrip("\n").split("\t")
                if len(p) < 3 or not p[0].isdigit() or int(p[0]) < since:
                    continue
                p += [""] * (6 - len(p))
                presses.append(Press(int(p[0]), p[1], p[2], p[3], p[4], p[5]))
    except OSError:
        pass
    return presses


def tmux_inventory() -> Dict[str, str]:
    """`tmux:<table>:<key>` -> command, without the logging wrapper."""
    inv = {}
    for table in ("prefix", "root"):
        for line in tmux("list-keys", "-T", table).splitlines():
            m = BIND_RE.match(line.strip())
            if not m or SKIP_RE.search(m.group(3)):
                continue
            command = re.sub(r'^run-shell -b "[^"]*keylog [^"]*" \\; ', "", m.group(4))
            inv[f"tmux:{table}:{key_label(m.group(3))}"] = command
    return inv


def user_tmux_keys() -> Set[str]:
    """Keys bound in tmux.conf itself (prefix and -n root), as opposed to tmux/plugin defaults."""
    keys = set()
    try:
        text = open(TMUX_CONF, encoding="utf-8").read()
    except OSError:
        return keys
    for line in text.splitlines():
        tokens = line.split()
        if not tokens or tokens[0] not in ("bind", "bind-key"):
            continue
        table, rest = "prefix", iter(tokens[1:])
        for tok in rest:
            if tok == "-T":
                table = next(rest, "")
            elif tok == "-N":
                next(rest, "")
            elif tok == "-n":
                table = "root"
            elif tok.startswith("-") and len(tok) > 1:
                continue
            else:
                keys.add(f"tmux:{table}:{key_label(tok.strip(chr(39) + chr(34)))}")
                break
    return keys


def cockpit_inventory() -> Dict[str, str]:
    """`cockpit:<key>` -> action, from the preset waymux materializes at runtime."""
    inv = {}
    try:
        with open(COCKPIT_TOML, "rb") as f:
            preset = tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError):
        return inv
    for ctx, binds in (("cockpit", preset.get("ui", {}).get("nav", {}).get("binds", {})),
                       ("cockpit-filter", preset.get("binds", {}))):
        for key, actions in binds.items():
            if key in ("Start", "@reload", ","):
                continue
            actions = actions if isinstance(actions, list) else [actions]
            shown = [a for a in actions if "keylog" not in a]
            inv[f"{ctx}:{key}"] = ", ".join(shown)
    inv["cockpit:enter"] = "Jump to the selected window"
    inv["cockpit:esc"] = "Close the Cockpit"
    return inv


# Cockpit actions by what they do, so aliases (g, G, gg, ctrl-g) count as one habit.
COCKPIT_ACTIONS = [
    ("__LAZYGIT__", "lazygitrs review"),
    ("__PATCH_MODE__", "lazygitrs patch mode"),
    ("__SWITCH_AWT__", "worktrees popup"),
    ("__JUMP_LAST_AGENT__", "jump to last agent"),
    ("__OPEN_PR_CHECKS__", "open PR checks"),
    ("__OPEN_PR__", "open PR"),
    ("__SWITCH_SESSION__", "session picker"),
    ("__SHIP_WORKTREE__", "ship worktree"),
    ("__NEW_WORKTREE__", "new worktree"),
    ("__SWEEP_WORKTREES__", "sweep worktrees"),
    ("__REAP_AGENTS__", "reap stale agents"),
    ("__CREATE_WINDOW__", "new window"),
    ("@reload", "fleet / agents view"),
    ("SwitchPreview", "help"),
    ("review-notes", "send review notes"),
    ("agent-action approve", "approve agent"),
    ("agent-action deny", "deny agent"),
    ("agent-action prompt", "prompt agent"),
    ("window-delete", "close window"),
    ("LiveInput", "live input to agent"),
    ("PreviewDown", "scroll preview"),
    ("PreviewUp", "scroll preview"),
    ("ExpandPreview", "resize preview"),
    ("ShrinkPreview", "resize preview"),
    ("FocusFilter", "filter"),
    ("Reload", "refresh"),
]


def action_label(key: str, command: str) -> str:
    """What a binding does, in words: Cockpit actions by name, tmux commands shortened."""
    if key.startswith("cockpit"):
        for needle, label in COCKPIT_ACTIONS:
            if needle in command:
                return label
    return shorten(command, 48)


def key_name(key: str) -> str:
    """`tmux:prefix:I` -> `Prefix + I`, `cockpit-filter:ctrl-g` -> `Cockpit ctrl-g`."""
    ctx, _, rest = key.partition(":")
    if ctx == "tmux":
        table, _, k = rest.partition(":")
        return f"Prefix + {k}" if table == "prefix" else k
    return f"Cockpit {rest}"


def press_id(p: Press) -> str:
    return f"tmux:{p.key}" if p.ctx == "tmux" else f"{p.ctx}:{p.key}"


def shorten(text: str, width: int = 58) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text if len(text) <= width else text[: width - 1] + "…"


def suggestions(presses: List[Press], inventory: Dict[str, str]) -> List[Tuple[int, str]]:
    """(count, advice) for each habit where a shorter path existed."""
    found: List[Tuple[int, str]] = []
    cockpit = [p for p in presses if p.ctx.startswith("cockpit")]

    waiting_jumps = [p for p in cockpit if p.key == "enter" and p.state in WAITING]
    if waiting_jumps:
        found.append((len(waiting_jumps),
                      "Cockpit → Enter on an agent waiting for you: Prefix + I (or Ctrl + Shift + I) "
                      "goes there in one chord, no list to scan."))

    own_git = [p for p in cockpit if p.key in GIT_KEYS and p.target and p.target == p.origin]
    if own_git:
        found.append((len(own_git),
                      "Cockpit → g on the window you came from: Ctrl + G opens lazygitrs directly."))

    sessions = [p for p in cockpit if p.key in ("s", "ctrl-s")]
    if sessions:
        found.append((len(sessions),
                      "Cockpit → s to reach the session picker: Prefix + s opens it directly."))

    # Cockpit visits that ended in Esc with no other key: a glance at agent state.
    ordered = sorted(presses, key=lambda p: p.ts)
    peeks, opened = 0, False
    for p in ordered:
        if p.ctx == "tmux" and p.key == "prefix:Space":
            opened = True
        elif p.ctx.startswith("cockpit"):
            if opened and p.key == "esc":
                peeks += 1
            opened = False
    if peeks >= 3:
        found.append((peeks,
                      "Cockpit opened and closed with Esc, nothing else: the status bar shows each "
                      "agent's state, and Prefix + I jumps only when one needs you."))

    # The same tmux key pressed 3+ times within 3 s: stepping through windows one by one.
    repeat_ok = {k for k, cmd in inventory.items() if "resize-pane" in cmd or "select-pane" in cmd}
    runs: collections.Counter = collections.Counter()
    tmux_presses = [p for p in ordered if p.ctx == "tmux"]
    keys_only = [p for p in tmux_presses if not MOUSE_RE.search(p.key)]
    streak = 1
    for prev, cur in zip(keys_only, keys_only[1:]):
        if cur.key == prev.key and cur.ts - prev.ts <= 3:
            streak += 1
            if streak == 3 and f"tmux:{cur.key}" not in repeat_ok:
                runs[cur.key] += 1
        else:
            streak = 1
    for key, n in runs.most_common(3):
        found.append((n,
                      f"{key} pressed 3+ times in a row: Prefix + f (window hints) or the window "
                      "number jumps straight to the target."))

    # Mouse clicks that moved the focus: each one leaves the home row and comes back.
    tab_clicks = [p for p in tmux_presses if p.key.startswith("root:MouseDown1Status") and p.state == "window"]
    if tab_clicks:
        found.append((len(tab_clicks),
                      "Click on a window tab: Prefix + f (home-row hints) or Prefix + <number> "
                      "switches without leaving the keyboard."))
    pane_clicks = [p for p in tmux_presses if p.key == "root:MouseDown1Pane" and p.state == "pane"]
    if pane_clicks:
        found.append((len(pane_clicks),
                      "Click to focus another pane: Ctrl + h/j/k/l moves between panes (and Neovim "
                      "splits) from the home row."))

    long_cds = shell_cd_count(min(p.ts for p in presses) if presses else int(time.time()) - 14 * 86400)
    if long_cds >= 5:
        found.append((long_cds,
                      "`cd <path>` typed in the shell: `j <part of the name>` jumps by frecency, "
                      "and Tab on an empty prompt opens the jump picker."))
    return sorted(found, reverse=True)


def shell_cd_count(since: int) -> int:
    """`cd` with a real path in atuin history (not `cd`, `cd -`, `cd ..`, `cd ~`)."""
    if not shutil.which("atuin"):
        return 0
    after = time.strftime("%Y-%m-%d", time.localtime(since))
    try:
        out = subprocess.run(
            ["atuin", "search", "--after", after, "--format", "{command}", "--limit", "100000", "^cd "],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except (OSError, subprocess.TimeoutExpired):
        return 0
    return sum(
        1 for line in out.splitlines()
        if line.startswith("cd ") and line[3:].strip() not in ("", "-", "..", "~", "../..")
    )


def report(days: int) -> int:
    since = int(time.time()) - days * 86400
    presses = load_presses(since)
    inventory = {**tmux_inventory(), **cockpit_inventory()}
    print(f"\n  Key telemetry, last {days} days ({len(presses)} presses)\n")
    if not presses:
        print("  No presses logged yet. Telemetry starts when tmux loads key-telemetry.py install")
        print(f"  and the Cockpit runs a waymux with `keylog`. Log: {KEYS_TSV}\n")
        return 0

    counts = collections.Counter(press_id(p) for p in presses)
    user = user_tmux_keys()

    # One row per action: the Cockpit's nav and filter modes and its aliases share a label.
    groups: Dict[Tuple[str, str], List[str]] = collections.defaultdict(list)
    for key, command in inventory.items():
        scope = "tmux" if key.startswith("tmux:") else "cockpit"
        if scope == "tmux" and key not in user:
            continue
        groups[(scope, action_label(key, command))].append(key)
    for key in counts:
        if not any(key in keys for keys in groups.values()):
            groups[("other", action_label(key, inventory.get(key, "")))].append(key)

    def keys_text(keys: List[str]) -> str:
        names = sorted({key_name(k) for k in keys}, key=len)
        return ", ".join(names[:3]) + (" …" if len(names) > 3 else "")

    used = sorted(((sum(counts[k] for k in keys), label, keys) for (_, label), keys in groups.items()
                   if any(k in counts for k in keys)), reverse=True)
    print("  Most used")
    for n, label, keys in used[:15]:
        print(f"    {n:5d}  {keys_text([k for k in keys if k in counts]):30s} {label}")

    unused = sorted((scope, label, keys) for (scope, label), keys in groups.items()
                    if not any(k in counts for k in keys))
    print("\n  Never used (yours: tmux.conf and the Cockpit)")
    for scope, label, keys in unused:
        print(f"           {keys_text(keys):30s} {label}")
    defaults = [k for k in inventory if k.startswith("tmux:") and k not in user and k not in counts]
    if defaults:
        print(f"    + {len(defaults)} tmux and plugin defaults never pressed")

    clicks = [p for p in presses if p.ctx == "tmux" and MOUSE_RE.search(p.key)]
    if clicks:
        moved = sum(1 for p in clicks if p.state in ("pane", "window"))
        print(f"\n  Mouse: {len(clicks)} clicks, {moved} of them to change pane or window")

    tips = suggestions(presses, inventory)
    print("\n  Faster paths")
    if not tips:
        print("    None found: you already take the short path everywhere the rules can see.")
    for n, tip in tips:
        print(f"    {n:5d}× {tip}")
    print()
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("install")
    rep = sub.add_parser("report")
    rep.add_argument("--days", type=int, default=14)
    args = parser.parse_args(argv)
    if args.cmd == "install":
        return install()
    return report(getattr(args, "days", 14))


if __name__ == "__main__":
    sys.exit(main())
