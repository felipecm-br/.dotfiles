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
import re
import shlex
import subprocess
from datetime import datetime
from typing import Dict, Any, List, Optional

DEFAULT_STATE_DIR = os.path.expanduser("~/.local/state/cockpit")
DEFAULT_SNAPSHOT_FILE = os.path.join(DEFAULT_STATE_DIR, "session-topology.json")
# The last snapshot of an earlier tmux server (before a reboot or a tmux restart). The automatic
# snapshot of the new server would overwrite it within seconds, so it is set aside here first,
# and `cockpit restore` reads it until it has been restored once.
PREVIOUS_SNAPSHOT_FILE = os.path.join(DEFAULT_STATE_DIR, "session-topology.previous.json")
RESTORED_SNAPSHOT_FILE = os.path.join(DEFAULT_STATE_DIR, "session-topology.restored.json")

# Agent resume. waymux sets `@ai_session` (`claude:<id>`) from the agent's hooks and ai-launch
# sets `@ai_launch` (`jail-claude-ask --model opus`); restore types the resume command into the
# pane, so every part is checked against these patterns, both when saved and when restored.
RESUMABLE = {"claude", "codex"}
SESSION_ID = re.compile(r"^[A-Za-z0-9_-]{8,64}$")
LAUNCH_WORD = re.compile(r"^[A-Za-z0-9._=:/-]{1,64}$")
SHELLS = {"zsh", "bash", "sh", "fish", "dash"}
LAUNCH_CHOICES = {"claude": "claude", "jail-claude": "claude", "jail-claude-ask": "claude", "codex": "codex"}


def process_children() -> Dict[str, List[tuple]]:
    """ppid -> [(pid, comm)] for every process, from one `ps`."""
    tree: Dict[str, List[tuple]] = {}
    try:
        r = subprocess.run(["ps", "-e", "-o", "pid=,ppid=,comm="], capture_output=True, text=True, timeout=2)
        for line in r.stdout.splitlines():
            parts = line.split(None, 2)
            if len(parts) == 3:
                tree.setdefault(parts[1], []).append((parts[0], parts[2].strip()))
    except Exception:
        pass
    return tree


def runs_under(tree: Dict[str, List[tuple]], pid: str, comm: str) -> bool:
    """Whether a process named `comm` runs anywhere below `pid` (a jailed agent sits a few
    levels down, under ai-jail, bwrap and ai-memory)."""
    todo = [pid]
    while todo:
        for child, name in tree.get(todo.pop(), []):
            if name == comm:
                return True
            todo.append(child)
    return False


def resume_of(session_tag: str, launch_tag: str) -> Optional[Dict[str, Any]]:
    """The agent, session id and launch words to resume a pane with, when all are safe."""
    agent, _, sid = session_tag.partition(":")
    if agent not in RESUMABLE or not SESSION_ID.match(sid):
        return None
    words = launch_tag.split()
    # The launch tag counts only for the same harness: Devin runs Claude's hooks too.
    if not words or LAUNCH_CHOICES.get(words[0]) != agent or not all(LAUNCH_WORD.match(w) for w in words):
        words = []
    return {"agent": agent, "id": sid, "launch": words}


def resume_command(resume: Optional[Dict[str, Any]]) -> Optional[str]:
    """The command that resumes a saved agent: the way ai-launch started it, else the CLI."""
    if not isinstance(resume, dict):
        return None
    r = resume_of(f"{resume.get('agent', '')}:{resume.get('id', '')}", " ".join(resume.get("launch") or []))
    if not r:
        return None
    if r["agent"] == "codex":
        return f"codex resume {r['id']}"
    if r["launch"]:
        return f"ai-launch {' '.join(r['launch'])} --resume {r['id']}"
    return f"claude --resume {r['id']}"

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
                if comm in {"nvim", "vim", "lazygit", "lazygitrs", "opencode", "devin", "claude", "codex", "agy", "agy-bin", "yazi", "btop", "htop"}:
                    if os.path.isfile(cmdline_file):
                        with open(cmdline_file, "rb") as f:
                            raw = f.read().decode("utf-8", errors="ignore").replace("\0", " ").strip()
                            if raw:
                                return raw
                    return comm
    except Exception:
        pass
    return None

def tmux_server() -> Optional[Dict[str, int]]:
    """The running tmux server's pid and start time, which tell one server from the next."""
    try:
        r = subprocess.run(["tmux", "display-message", "-p", "#{pid} #{start_time}"], capture_output=True, text=True, timeout=1)
        pid, start = r.stdout.split()
        return {"pid": int(pid), "start_time": int(start)}
    except Exception:
        return None


def from_earlier_server(topo: Dict[str, Any], server: Optional[Dict[str, int]]) -> bool:
    """Whether a saved snapshot was taken by a tmux server other than `server`."""
    if not server:
        return False
    saved = topo.get("server")
    if isinstance(saved, dict):
        return saved != server
    # Snapshots from before the server field: anything older than this server's start.
    return int(topo.get("timestamp") or 0) < server["start_time"]


def capture_topology() -> Optional[Dict[str, Any]]:
    format_str = (
        "#{session_name}\t#{window_index}\t#{window_name}\t#{window_layout}\t"
        "#{pane_index}\t#{pane_id}\t#{pane_current_path}\t#{pane_current_command}\t"
        "#{pane_pid}\t#{session_attached}\t#{window_active}\t#{pane_active}\t"
        "#{@ai_agent_state_raw}\t#{@ai_session}\t#{@ai_launch}"
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

    # Only the newline: strip() would eat the empty trailing fields of the last pane.
    raw_lines = r.stdout.rstrip("\n").split("\n")
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
    tree = process_children()

    for line in raw_lines:
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 15:
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
            session_tag,
            launch_tag,
        ) = parts[:15]

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
        # Resume only an agent still running in the pane: the tags outlive it.
        resume = resume_of(session_tag, launch_tag)
        if resume and not runs_under(tree, p_pid, resume["agent"]):
            resume = None

        sessions_map[s_name]["windows"][w_idx]["panes"].append({
            "index": int(p_idx),
            "id": p_id,
            "path": p_path,
            "shell_cmd": p_cmd,
            "foreground_cmd": fg_cmd,
            "agent_state": agent_state if agent_state else None,
            "resume": resume,
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
        "server": tmux_server(),
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
    if filepath == DEFAULT_SNAPSHOT_FILE and os.path.isfile(filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                if from_earlier_server(json.load(f), topo.get("server")):
                    os.replace(filepath, PREVIOUS_SNAPSHOT_FILE)
        except Exception:
            pass
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

def default_restore_file() -> str:
    """The earlier server's snapshot while it has not been restored, else the current one."""
    return PREVIOUS_SNAPSHOT_FILE if os.path.isfile(PREVIOUS_SNAPSHOT_FILE) else DEFAULT_SNAPSHOT_FILE


def restore_snapshot(filepath: Optional[str] = None, dry_run: bool = False, switch: bool = True) -> bool:
    c = load_theme_colors()
    filepath = filepath or default_restore_file()
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
    home = os.path.expanduser("~")

    def pane_path(pane: Dict[str, Any]) -> str:
        path = pane.get("path") or home
        return path if os.path.isdir(path) else home

    def relaunch(target: str, pane: Dict[str, Any], cd: bool = False) -> None:
        cmd = resume_command(pane.get("resume"))
        fg = pane.get("foreground_cmd")
        if not cmd and fg and not fg.startswith(("bash", "zsh")):
            cmd = fg
        if cd:
            # An adopted pane started elsewhere: an agent resumes per project directory.
            go = f"cd -- {shlex.quote(pane_path(pane))}"
            cmd = f"{go} && {cmd}" if cmd else go
        if cmd:
            subprocess.run(["tmux", "send-keys", "-t", target, "-l", cmd])
            subprocess.run(["tmux", "send-keys", "-t", target, "Enter"])

    def window_size(w: Dict[str, Any]) -> List[str]:
        # A detached session is 80x24 unless told otherwise, too small to split back.
        m = re.match(r"^[0-9a-f]{4},(\d+)x(\d+),", w.get("layout") or "")
        return ["-x", m.group(1), "-y", m.group(2)] if m else []

    def build_window(create: List[str], w: Dict[str, Any], adopt: Optional[str] = None) -> None:
        """Creates the window with `create` (new-session or new-window), or takes over the
        lone shell pane `adopt`, splits it back into its panes, applies the saved layout, then
        relaunches every pane."""
        panes = w.get("panes") or [{}]
        if adopt:
            first = adopt
        else:
            r = subprocess.run(create + ["-c", pane_path(panes[0]), "-P", "-F", "#{pane_id}"], capture_output=True, text=True)
            first = r.stdout.strip()
            if r.returncode != 0 or not first:
                print(f"    {c['red']}✗ {r.stderr.strip()}{c['reset']}")
                return
        targets = [first]
        for pane in panes[1:]:
            # Split the last pane so panes keep their order; the layout then places them.
            r = subprocess.run(["tmux", "split-window", "-d", "-t", targets[-1], "-c", pane_path(pane), "-P", "-F", "#{pane_id}"], capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                targets.append(r.stdout.strip())
        if w.get("layout"):
            subprocess.run(["tmux", "select-layout", "-t", first, w["layout"]], capture_output=True)
        for n, (target, pane) in enumerate(zip(targets, panes)):
            relaunch(target, pane, cd=bool(adopt) and n == 0)

    def worth_rebuilding(w: Dict[str, Any]) -> bool:
        panes = w.get("panes") or []
        return len(panes) > 1 or any(resume_command(p.get("resume")) or (p.get("foreground_cmd") and not p["foreground_cmd"].startswith(("bash", "zsh"))) for p in panes)

    def describe(w: Dict[str, Any]) -> str:
        panes = w.get("panes") or []
        resumed = sum(1 for p in panes if resume_command(p.get("resume")))
        extra = f", {resumed} agent{'s' if resumed != 1 else ''} resumed" if resumed else ""
        return f"[{w['index']}] '{w.get('name', '')}' ({len(panes)} pane{'s' if len(panes) != 1 else ''}{extra})"

    for s in sessions:
        s_name = s["name"]
        windows = s.get("windows", [])
        if not windows:
            continue

        if s_name in existing_sessions:
            print(f"  {c['yellow']}• Session '{s_name}' already active (checking missing windows)...{c['reset']}")
            skipped_count += 1
            # index -> the lone pane of a window that is only a fresh shell (the session a new
            # terminal opens after a reboot), which restore may take over.
            current: Dict[str, Optional[str]] = {}
            try:
                rw = subprocess.run(
                    ["tmux", "list-windows", "-t", s_name, "-F", "#{window_index}\t#{window_panes}\t#{pane_current_command}\t#{pane_id}"],
                    capture_output=True,
                    text=True,
                )
                for line in rw.stdout.splitlines():
                    idx, n, cmd, pane_id = (line.split("\t") + ["", "", "", ""])[:4]
                    current[idx] = pane_id if n == "1" and cmd in SHELLS else None
            except Exception:
                pass

            for w in windows:
                idx = str(w["index"])
                if idx not in current:
                    print(f"    {c['green']}+ Recreating window {describe(w)}{c['reset']}")
                    if not dry_run:
                        build_window(["tmux", "new-window", "-d", "-t", f"{s_name}:{idx}", "-n", w.get("name", "win")], w)
                elif current[idx] and worth_rebuilding(w):
                    print(f"    {c['green']}+ Rebuilding fresh window {describe(w)}{c['reset']}")
                    if not dry_run:
                        build_window([], w, adopt=current[idx])
            continue

        print(f"  {c['green']}✓ Restoring session '{s_name}' ({len(windows)} windows){c['reset']}")
        for w in windows:
            print(f"    {c['dim']}{describe(w)}{c['reset']}")
        if not dry_run:
            first = windows[0]
            build_window(["tmux", "new-session", "-d", "-s", s_name, "-n", first.get("name", "0")] + window_size(first), first)
            for w in windows[1:]:
                build_window(["tmux", "new-window", "-d", "-t", f"{s_name}:{w['index']}", "-n", w.get("name", str(w["index"]))], w)

        restored_count += 1

    # Select active session/window if present
    act_sess = topo.get("active_session")
    act_win = topo.get("active_window")
    if not dry_run and switch and act_sess:
        try:
            target = f"{act_sess}:{act_win}" if act_win else act_sess
            subprocess.run(["tmux", "switch-client", "-t", target], capture_output=True)
        except Exception:
            pass

    print(f"\n{c['green']}{c['bold']}✓ Restoration Complete:{c['reset']} {restored_count} created, {skipped_count} updated.")
    if not dry_run and filepath == PREVIOUS_SNAPSHOT_FILE:
        # Restored once: a second `cockpit restore` must not bring back windows closed since.
        os.replace(PREVIOUS_SNAPSHOT_FILE, RESTORED_SNAPSHOT_FILE)
    return True

def boot_time() -> int:
    try:
        with open("/proc/stat", "r") as f:
            for line in f:
                if line.startswith("btime "):
                    return int(line.split()[1])
    except Exception:
        pass
    return 0


def auto_restore(created_session: str = "") -> bool:
    """`cockpit restore` on the first tmux session after a boot (the `session-created` hook).

    Only a snapshot taken before this boot counts, so restarting tmux without a reboot never
    brings back sessions closed on purpose; once restored, the snapshot is retired, so later
    sessions do nothing. Output goes to restore.log; tmux shows a one-line summary."""
    import fcntl
    os.makedirs(DEFAULT_STATE_DIR, exist_ok=True)
    lock = open(os.path.join(DEFAULT_STATE_DIR, "restore.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return False  # another terminal is restoring

    def taken_at(path: str) -> int:
        try:
            with open(path, "r", encoding="utf-8") as f:
                return int(json.load(f).get("timestamp") or 0)
        except Exception:
            return -1

    boot = int(os.environ.get("COCKPIT_BOOT_TIME") or boot_time())  # override for tests
    # The focus hook may not have set the old server's snapshot aside yet.
    if 0 <= taken_at(DEFAULT_SNAPSHOT_FILE) < boot:
        os.replace(DEFAULT_SNAPSHOT_FILE, PREVIOUS_SNAPSHOT_FILE)
    if not 0 <= taken_at(PREVIOUS_SNAPSHOT_FILE) < boot:
        return False

    with open(PREVIOUS_SNAPSHOT_FILE, "r", encoding="utf-8") as f:
        topo = json.load(f)
    names = [s.get("name") for s in topo.get("sessions", [])]
    agents = sum(1 for s in topo.get("sessions", []) for w in s.get("windows", []) for p in w.get("panes", []) if resume_command(p.get("resume")))
    log = os.path.join(DEFAULT_STATE_DIR, "restore.log")
    stdout = sys.stdout
    with open(log, "w", encoding="utf-8") as out:
        sys.stdout = out
        try:
            # Stay in the session the terminal opened when the snapshot has it; else go to the
            # one that was active (the new terminal's session is then a spare shell).
            done = restore_snapshot(PREVIOUS_SNAPSHOT_FILE, switch=created_session not in names)
        finally:
            sys.stdout = stdout
    msg = f"cockpit: restored {len(names)} session{'s' if len(names) != 1 else ''}"
    msg += f", {agents} agent{'s' if agents != 1 else ''} resumed" if agents else ""
    subprocess.run(["tmux", "display-message", "-d", "5000", msg if done else f"cockpit: restore failed, see {log}"], capture_output=True)
    return done


def status_snapshot(filepath: Optional[str] = None):
    c = load_theme_colors()
    if filepath is None and os.path.isfile(PREVIOUS_SNAPSHOT_FILE):
        print(f"\n{c['green']}{c['bold']}Not restored yet:{c['reset']} the snapshot below is from before the last reboot or tmux restart; `cockpit restore` uses it.")
        filepath = PREVIOUS_SNAPSHOT_FILE
    filepath = filepath or DEFAULT_SNAPSHOT_FILE
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
    p_rest.add_argument("--file", type=str, default=None)
    p_rest.add_argument("--dry-run", action="store_true")
    p_rest.add_argument("--auto", action="store_true", help="once per boot, from the session-created hook")
    p_rest.add_argument("--session", type=str, default="", help="with --auto: the session the hook fired for")

    p_stat = subparsers.add_parser("status", help="Show saved snapshot information")
    p_stat.add_argument("--file", type=str, default=None)

    args = parser.parse_args()

    if args.command == "snapshot":
        success = save_snapshot(filepath=args.file, quiet=args.quiet)
        sys.exit(0 if success else 1)
    elif args.command == "restore":
        if args.auto:
            auto_restore(args.session)
            sys.exit(0)
        success = restore_snapshot(filepath=args.file, dry_run=args.dry_run)
        sys.exit(0 if success else 1)
    elif args.command == "status":
        status_snapshot(filepath=args.file)
    else:
        # Default action: status if exists, else save
        if os.path.isfile(DEFAULT_SNAPSHOT_FILE) or os.path.isfile(PREVIOUS_SNAPSHOT_FILE):
            status_snapshot()
        else:
            save_snapshot(filepath=DEFAULT_SNAPSHOT_FILE)

if __name__ == "__main__":
    main()
