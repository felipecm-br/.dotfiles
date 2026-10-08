#!/usr/bin/env bash
# scripts/drift-doctor.sh — Automated Cockpit Health & Drift Diagnostic Tool
set -uo pipefail

rc=0
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; rc=1; }
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }

printf '=== [Flow Doctor] Auditing Cockpit Integrity & System Drift ===\n\n'

# 1. Lazygitrs Capability Check
lzg_resolved="$(command -v lazygitrs 2>/dev/null || echo "")"
if [ -x "$lzg_resolved" ]; then
  if "$lzg_resolved" --help 2>&1 | grep -q -- '--commits'; then
    ok "lazygitrs supports Dual-Diff (--commits flag present: $lzg_resolved)"
  else
    warn "lazygitrs in PATH ($lzg_resolved) lacks --commits support (cockpit features missing)"
  fi
else
  warn "lazygitrs not found in PATH"
fi

# 2. Binary Drift Check for waymaker (wm) and acpd
for bin in wm acpd; do
  declare -A bin_seen=()
  bin_count=0
  for p in "$HOME/.local/bin/$bin" "$HOME/.cargo/bin/$bin" "$(command -v "$bin" 2>/dev/null)"; do
    [ -n "$p" ] && [ -x "$p" ] || continue
    v=$("$p" --version 2>&1 | head -n1)
    if [ -z "${bin_seen[$v]:-}" ]; then
      bin_seen[$v]="$p"
      bin_count=$((bin_count + 1))
    fi
  done
  if (( bin_count > 1 )); then
    warn "$bin: multiple versions found on disk (${!bin_seen[*]})"
  elif (( bin_count == 1 )); then
    ok "$bin: single binary version consistency (${!bin_seen[*]})"
  else
    warn "$bin: not found in standard paths"
  fi
  unset bin_seen
done

# 3. keyd overload_tap_timeout Check
if grep -q "overload_tap_timeout" /etc/keyd/default.conf 2>/dev/null; then
  ok "keyd: overload_tap_timeout guard is active in /etc/keyd/default.conf"
else
  warn "keyd: /etc/keyd/default.conf lacks 'overload_tap_timeout = 200'. Run: sudo tee /etc/keyd/default.conf <<<'[global]\noverload_tap_timeout = 200\n[ids]\n*\n[main]\ncapslock = overload(control, esc)' && sudo keyd reload"
fi

# 4. tmux History Buffer Check
hl=$(tmux show-option -gv history-limit 2>/dev/null || echo 0)
if (( hl >= 30000 )); then
  ok "tmux: history-limit is adequate ($hl lines >= 30000)"
else
  warn "tmux: history-limit ($hl) is below recommended 50000 lines (risk of agent log truncation)"
fi

# 5. acpd Daemon Health & Token Check
token_path="${XDG_RUNTIME_DIR:-/run/user/$UID}/acpd/token"
if [ -f "$token_path" ]; then
  token="$(cat "$token_path" 2>/dev/null || true)"
  if [ -n "$token" ]; then
    code=$(curl -s -m 0.5 -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:4040/rpc \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"agentState/list","id":1}' 2>/dev/null || echo "000")
    if [ "$code" = "200" ]; then
      ok "acpd: RPC online and authorized (HTTP 200, port 4040)"
    else
      warn "acpd: RPC returned HTTP $code (daemon down or token mismatch)"
    fi
  else
    warn "acpd: token file is empty ($token_path)"
  fi
else
  warn "acpd: token file not found at $token_path"
fi

printf '\n=== [Flow Doctor] Audit Complete (exit code: %d) ===\n' "$rc"
exit "$rc"
