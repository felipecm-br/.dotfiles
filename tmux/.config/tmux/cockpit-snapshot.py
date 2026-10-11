#!/usr/bin/env python3
"""
cockpit-snapshot.py — Cockpit session topology snapshot & post-reboot restore engine.
Captures active Tmux sessions, windows, pane paths, layouts, and commands into
~/.local/state/cockpit/session-topology.json and restores them after system reboot.
"""

import sys
import os
import json
import time
import argparse
import subprocess
from datetime import datetime
from typing import Dict, Any, List, Optional

DEFAULT_STATE_DIR = os.path.expanduser("~/.local/state/cockpit")
DEFAULT_SNAPSHOT_FILE = os.path.join(DEFAULT_STATE_DIR, "session-topology.json")

def load_theme_colors() -> Dict[str, str]:
    colors = {
        "cyan": "\033[36m",
        "yellow": "\033[33m",
        "green": "\033[32m",
        "magenta": "\033[35m",
        "blue": "\033[34m",
        "red": "\033[31m",
        "dim": "\033[2m",
        "bold": "\033[1m",
        "reset": "\033[0m",
    }
    return colors

def get_git_info(path: str) -> Optional[Dict[str, str]]:
    if not os.path.isdir(path):
        return None
    try:
        r = subprocess.run(
            ["git", "-C", path, "rev-parse", "--show-toplevel", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=1,
        )
        if r.returncode == 0:
            lines = r.stdout.strip().split("\n")
            if len(lines) >= 2:
                return {"root": lines[0], "branch": lines[1]}
    except Exception:
        pass
    return None

def inspect_pane_foreground_cmd(pid: str) -> Optional[str]:
    """Inspect descendants to detect meaningful foreground CLI applications."""
    try:
        r = subprocess.run(["pgrep", "-P", pid], capture_output=True, text=True, timeout=1)
        if r.returncode != 0:
            return None
        child_pids = r.stdout.strip().split()
        for cpid in reversed(child_pids):
            comm_file = f"/proc/{cpid}/comm"
            cmdline_file = f"/proc/{cpid}/cmdline"
            if os.path.isfile(comm_file):
                with open(comm_file, "r") as f:
                    comm = f.read().strip()
                if comm in {"nvim", "vim", "lazygit", "lazygitrs", "opencode", "yazi", "btop", "htop"}:
                    if os.path.isfile(cmdline_file):
                        with open(cmdline_file, "rb") as f:
                            raw = f.read().decode("utf-8", errors="ignore").replace("\0", " ").strip()
                            if raw:
                                return raw
                    return comm
    except Exception:
        pass
    return None

def capture_topology() -> Optional[Dict[str, Any]]:
    format_str = (
        "#{session_name}\t#{window_index}\t#{window_name}\t#{window_layout}\t"
        "#{pane_index}\t#{pane_id}\t#{pane_current_path}\t#{pane_current_command}\t"
        "#{pane_pid}\t#{session_attached}\t#{window_active}\t#{pane_active}\t"
        "#{@ai_agent_state_raw}"
    )
    try:
        r = subprocess.run(
            ["tmux", "list-panes", "-a", "-F", format_str],
            capture_output=True,
            text=True,
            timeout=3,
        )
        if r.returncode != 0:
            return None
    except Exception:
        return None

    raw_lines = r.stdout.strip().split("\n")
    if not raw_lines or raw_lines == [""]:
        return None

    active_session = None
    active_window = None

    # Get active session/window
    try:
        curr = subprocess.run(
            ["tmux", "display-message", "-p", "#{session_name}\t#{window_index}"],
            capture_output=True,
            text=True,
            timeout=1,
        )
        if curr.returncode == 0:
            cparts = curr.stdout.strip().split("\t")
            if len(cparts) >= 2:
                active_session, active_window = cparts[0], cparts[1]
    except Exception:
        pass

    sessions_map: Dict[str, Dict[str, Any]] = {}
    worktrees_seen: Dict[str, Dict[str, str]] = {}

    for line in raw_lines:
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 13:
            continue

        (
            s_name,
            w_idx,
            w_name,
            w_layout,
            p_idx,
            p_id,
            p_path,
            p_cmd,
            p_pid,
            s_att,
            w_act,
            p_act,
            agent_state,
        ) = parts[:13]

        # Ignore popup/internal sessions
        if s_name.startswith("_popups") or s_name == "_popups":
            continue

        if s_name not in sessions_map:
            sessions_map[s_name] = {
                "name": s_name,
                "attached": s_att == "1",
                "windows": {},
            }

        if w_idx not in sessions_map[s_name]["windows"]:
            sessions_map[s_name]["windows"][w_idx] = {
                "index": int(w_idx),
                "name": w_name,
                "layout": w_layout,
                "active": w_act == "1",
                "panes": [],
            }

        # Check for meaningful foreground command (e.g. nvim, lazygitrs)
        fg_cmd = inspect_pane_foreground_cmd(p_pid)

        sessions_map[s_name]["windows"][w_idx]["panes"].append({
            "index": int(p_idx),
            "id": p_id,
            "path": p_path,
            "shell_cmd": p_cmd,
            "foreground_cmd": fg_cmd,
            "agent_state": agent_state if agent_state else None,
            "active": p_act == "1",
        })

        # Track worktree
        if p_path not in worktrees_seen:
            git_info = get_git_info(p_path)
            if git_info:
                worktrees_seen[p_path] = git_info

    # Convert windows map to list
    sessions_list = []
    for s_name, s_data in sessions_map.items():
        windows_list = sorted(s_data["windows"].values(), key=lambda w: w["index"])
        sessions_list.append({
            "name": s_data["name"],
            "attached": s_data["attached"],
            "windows": windows_list,
        })

    worktrees_list = [
        {"path": path, "root": info["root"], "branch": info["branch"]}
        for path, info in worktrees_seen.items()
    ]

    return {
        "timestamp": int(time.time()),
        "datetime": datetime.now().isoformat(),
        "active_session": active_session,
        "active_window": active_window,
        "sessions": sessions_list,
        "worktrees": worktrees_list,
    }

def save_snapshot(filepath: str = DEFAULT_SNAPSHOT_FILE, quiet: bool = False) -> bool:
    topo = capture_topology()
    if not topo:
        if not quiet:
            print("Error: No active Tmux sessions found to snapshot.", file=sys.stderr)
        return False

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    temp_file = f"{filepath}.tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(topo, f, indent=2)
    os.replace(temp_file, filepath)

    if not quiet:
        c = load_theme_colors()
        num_sessions = len(topo["sessions"])
        num_windows = sum(len(s["windows"]) for s in topo["sessions"])
        num_wt = len(topo["worktrees"])
        print(f"{c['green']}✓ Cockpit topology snapshot saved successfully.{c['reset']}")
        print(f"  {c['dim']}File:{c['reset']} {filepath}")
        print(f"  {c['dim']}Summary:{c['reset']} {num_sessions} sessions, {num_windows} windows, {num_wt} worktrees captured.")

    return True

def restore_snapshot(filepath: str = DEFAULT_SNAPSHOT_FILE, dry_run: bool = False) -> bool:
    c = load_theme_colors()
    if not os.path.isfile(filepath):
        print(f"{c['red']}Error: Snapshot file not found: {filepath}{c['reset']}", file=sys.stderr)
        return False

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            topo = json.load(f)
    except Exception as e:
        print(f"{c['red']}Error reading snapshot JSON: {e}{c['reset']}", file=sys.stderr)
        return False

    sessions = topo.get("sessions", [])
    if not sessions:
        print(f"{c['yellow']}Snapshot is empty (0 sessions recorded).{c['reset']}")
        return False

    # Check existing sessions in Tmux
    try:
        r = subprocess.run(["tmux", "list-sessions", "-F", "#{session_name}"], capture_output=True, text=True)
        existing_sessions = set(r.stdout.strip().split("\n")) if r.returncode == 0 else set()
    except Exception:
        existing_sessions = set()

    print(f"\n{c['cyan']}{c['bold']}󱂬 Restoring Cockpit Session Topology...{c['reset']}")
    print(f"  {c['dim']}Snapshot Date:{c['reset']} {topo.get('datetime', 'unknown')} ({len(sessions)} sessions)")
    print(f"  {c['dim']}────────────────────────────────────────────────────────────{c['reset']}")

    restored_count = 0
    skipped_count = 0

    for s in sessions:
        s_name = s["name"]
        windows = s.get("windows", [])
        if not windows:
            continue

        if s_name in existing_sessions:
            print(f"  {c['yellow']}• Session '{s_name}' already active (checking missing windows)...{c['reset']}")
            skipped_count += 1
            # Check missing windows
            try:
                rw = subprocess.run(
                    ["tmux", "list-windows", "-t", s_name, "-F", "#{window_index}"],
                    capture_output=True,
                    text=True,
                )
                curr_w_indices = set(rw.stdout.strip().split("\n")) if rw.returncode == 0 else set()
            except Exception:
                curr_w_indices = set()

            for w in windows:
                w_idx = str(w["index"])
                if w_idx not in curr_w_indices:
                    w_name = w.get("name", "win")
                    first_pane = w["panes"][0] if w.get("panes") else {}
                    p_path = first_pane.get("path", os.path.expanduser("~"))
                    if not os.path.isdir(p_path):
                        p_path = os.path.expanduser("~")
                    print(f"    {c['green']}+ Recreating window [{w_idx}] '{w_name}' in '{p_path}'{c['reset']}")
                    if not dry_run:
                        subprocess.run([
                            "tmux", "new-window", "-d", "-t", f"{s_name}:{w_idx}",
                            "-n", w_name, "-c", p_path
                        ])
                        if w.get("layout"):
                            subprocess.run(["tmux", "select-layout", "-t", f"{s_name}:{w_idx}", w["layout"]])
            continue

        # Session does not exist -> create fresh session
        first_win = windows[0]
        first_pane = first_win["panes"][0] if first_win.get("panes") else {}
        first_path = first_pane.get("path", os.path.expanduser("~"))
        if not os.path.isdir(first_path):
            first_path = os.path.expanduser("~")
        first_name = first_win.get("name", "0")

        print(f"  {c['green']}✓ Restoring session '{s_name}' ({len(windows)} windows) in '{first_path}'{c['reset']}")

        if not dry_run:
            subprocess.run([
                "tmux", "new-session", "-d", "-s", s_name,
                "-n", first_name, "-c", first_path
            ])
            # Restore first window layout
            if first_win.get("layout"):
                subprocess.run(["tmux", "select-layout", "-t", f"{s_name}:{first_win['index']}", first_win["layout"]])

            # Relaunch foreground command if present (e.g. lazygitrs)
            if first_pane.get("foreground_cmd") and not first_pane["foreground_cmd"].startswith("bash") and not first_pane["foreground_cmd"].startswith("zsh"):
                fg = first_pane["foreground_cmd"]
                subprocess.run(["tmux", "send-keys", "-t", f"{s_name}:{first_win['index']}", fg, "Enter"])

            # Create remaining windows in session
            for w in windows[1:]:
                w_idx = w["index"]
                w_name = w.get("name", str(w_idx))
                w_pane = w["panes"][0] if w.get("panes") else {}
                w_path = w_pane.get("path", os.path.expanduser("~"))
                if not os.path.isdir(w_path):
                    w_path = os.path.expanduser("~")

                subprocess.run([
                    "tmux", "new-window", "-d", "-t", f"{s_name}:{w_idx}",
                    "-n", w_name, "-c", w_path
                ])
                if w.get("layout"):
                    subprocess.run(["tmux", "select-layout", "-t", f"{s_name}:{w_idx}", w["layout"]])

                if w_pane.get("foreground_cmd") and not w_pane["foreground_cmd"].startswith("bash") and not w_pane["foreground_cmd"].startswith("zsh"):
                    fg = w_pane["foreground_cmd"]
                    subprocess.run(["tmux", "send-keys", "-t", f"{s_name}:{w_idx}", fg, "Enter"])

        restored_count += 1

    # Select active session/window if present
    act_sess = topo.get("active_session")
    act_win = topo.get("active_window")
    if not dry_run and act_sess:
        try:
            target = f"{act_sess}:{act_win}" if act_win else act_sess
            subprocess.run(["tmux", "switch-client", "-t", target], capture_output=True)
        except Exception:
            pass

    print(f"\n{c['green']}{c['bold']}✓ Restoration Complete:{c['reset']} {restored_count} created, {skipped_count} updated.")
    return True

def status_snapshot(filepath: str = DEFAULT_SNAPSHOT_FILE):
    c = load_theme_colors()
    if not os.path.isfile(filepath):
        print(f"{c['yellow']}No snapshot found at {filepath}{c['reset']}")
        return

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            topo = json.load(f)
    except Exception as e:
        print(f"{c['red']}Error reading snapshot JSON: {e}{c['reset']}")
        return

    ts = topo.get("timestamp", 0)
    age_sec = int(time.time()) - ts
    age_str = f"{age_sec // 60}m ago" if age_sec < 3600 else f"{age_sec // 3600}h {(age_sec % 3600) // 60}m ago"

    sessions = topo.get("sessions", [])
    worktrees = topo.get("worktrees", [])

    print(f"\n{c['cyan']}{c['bold']}󱂬 Cockpit Session Topology Status{c['reset']}")
    print(f"  {c['dim']}Snapshot file:{c['reset']} {filepath}")
    print(f"  {c['dim']}Captured at:{c['reset']}   {topo.get('datetime', 'unknown')} ({age_str})")
    print(f"  {c['dim']}Sessions:{c['reset']}      {len(sessions)}")
    print(f"  {c['dim']}Worktrees:{c['reset']}     {len(worktrees)}\n")

    for s in sessions:
        wins = s.get("windows", [])
        print(f"  {c['yellow']}• Session: {s['name']}{c['reset']} ({len(wins)} windows)")
        for w in wins:
            panes = w.get("panes", [])
            path = panes[0].get("path", "") if panes else ""
            print(f"    [{w['index']}] {w['name']:<12} {c['dim']}{path}{c['reset']}")
    print("")

def main():
    parser = argparse.ArgumentParser(description="Cockpit Session Topology Snapshot & Restore Engine")
    subparsers = parser.add_subparsers(dest="command")

    p_snap = subparsers.add_parser("snapshot", help="Save current Tmux session topology")
    p_snap.add_argument("--file", type=str, default=DEFAULT_SNAPSHOT_FILE)
    p_snap.add_argument("--quiet", action="store_true")

    p_rest = subparsers.add_parser("restore", help="Restore Tmux sessions and windows from snapshot")
    p_rest.add_argument("--file", type=str, default=DEFAULT_SNAPSHOT_FILE)
    p_rest.add_argument("--dry-run", action="store_true")

    p_stat = subparsers.add_parser("status", help="Show saved snapshot information")
    p_stat.add_argument("--file", type=str, default=DEFAULT_SNAPSHOT_FILE)

    args = parser.parse_args()

    if args.command == "snapshot":
        success = save_snapshot(filepath=args.file, quiet=args.quiet)
        sys.exit(0 if success else 1)
    elif args.command == "restore":
        success = restore_snapshot(filepath=args.file, dry_run=args.dry_run)
        sys.exit(0 if success else 1)
    elif args.command == "status":
        status_snapshot(filepath=args.file)
    else:
        # Default action: status if exists, else save
        if os.path.isfile(DEFAULT_SNAPSHOT_FILE):
            status_snapshot(DEFAULT_SNAPSHOT_FILE)
        else:
            save_snapshot(filepath=DEFAULT_SNAPSHOT_FILE)

if __name__ == "__main__":
    main()
