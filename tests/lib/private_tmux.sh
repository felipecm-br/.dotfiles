# tests/lib/private_tmux.sh — source from a test (after `set -u` is fine) to run it against:
#   - a private tmux server: TMUX points at it, so every bare `tmux` call, the test's and the
#     scripts' under test, lands there instead of the live session (and its hooks/telemetry);
#   - a sandboxed HOME that links this checkout's packages the way stow would, so scripts that
#     call ~/.config/... or ~/.local/bin/... run the code under test and never touch
#     ~/.local/state;
#   - an unusable WAYMUX_PORT, so no waymux client call reaches the live daemon.
# Cleanup runs on EXIT; a test that sets its own EXIT trap must call private_tmux_cleanup.

_PT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_PT_SOCK="test-$$-${RANDOM}"
_PT_HOME="$(mktemp -d)"

for _pt_pkg in tmux awt waymaker waymux utils; do
  [ -d "$_PT_ROOT/$_pt_pkg" ] || continue
  while IFS= read -r _pt_rel; do
    mkdir -p "$(dirname "$_PT_HOME/$_pt_rel")"
    ln -sfn "$_PT_ROOT/$_pt_pkg/$_pt_rel" "$_PT_HOME/$_pt_rel"
  done < <(cd "$_PT_ROOT/$_pt_pkg" && find . \( -type f -o -type l \) | sed 's|^\./||')
done
mkdir -p "$_PT_HOME/.local/state"
# Deterministic git identity for repos the tests create (the real ~/.gitconfig is out of reach).
printf '[user]\n\tname = test\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' \
  > "$_PT_HOME/.gitconfig"

# Window-lifecycle options the scripts rely on, mirrored from tmux.conf. The full config is not
# loaded: its hooks would call waymux and flow telemetry on every focus change.
printf 'set -g base-index 0\nset -g pane-base-index 0\nset -g renumber-windows on\nset -g detach-on-destroy off\n' \
  > "$_PT_HOME/test-tmux.conf"
command tmux -L "$_PT_SOCK" -f "$_PT_HOME/test-tmux.conf" new-session -d -s _test_bootstrap
_PT_SOCKET_PATH="$(command tmux -L "$_PT_SOCK" display-message -p '#{socket_path}')"

export TMUX="$_PT_SOCKET_PATH,0,0"
unset TMUX_PANE
export HOME="$_PT_HOME"
export PATH="$_PT_HOME/.local/bin:$PATH"
export WAYMUX_PORT=9
# A shell started through ai-launch carries the wrapper's WAYMUX_* settings; they would point
# these tests at the real quota state and armed-choice file. Drop them.
for _v in $(env | sed -n 's/^\(WAYMUX_\(QUOTA\|LAUNCH\|SWITCH\)_[A-Z_]*\)=.*/\1/p'); do unset "$_v"; done

private_tmux_cleanup() {
  command tmux -L "$_PT_SOCK" kill-server 2>/dev/null || true
  rm -f "$_PT_SOCKET_PATH"
  rm -rf "$_PT_HOME"
}
trap private_tmux_cleanup EXIT
