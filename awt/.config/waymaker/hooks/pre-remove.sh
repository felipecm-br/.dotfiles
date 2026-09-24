#!/usr/bin/env bash
# Matchmaker / Waymaker Agent Worktree Lifecycle Hook: pre-remove
# Args: <worktree_path> <branch_name>

wt_path="$1"
branch_name="$2"

[ -d "$wt_path" ] || exit 0

# 1. Project-level custom script hooks (if defined in repository)
if [[ -x "$wt_path/.hooks/pre-remove" ]]; then
    "$wt_path/.hooks/pre-remove" "$wt_path" "$branch_name"
    exit $?
elif [[ -x "$wt_path/.awt/hooks/pre-remove" ]]; then
    "$wt_path/.awt/hooks/pre-remove" "$wt_path" "$branch_name"
    exit $?
elif [[ -x "$wt_path/.git/hooks/pre-worktree-remove" ]]; then
    "$wt_path/.git/hooks/pre-worktree-remove" "$wt_path" "$branch_name"
    exit $?
fi

# 2. Declarative hooks from .awt.yaml / .workmux.yaml
config_file=""
for cf in "$wt_path/.awt.yaml" "$wt_path/.awt/config.yaml" "$wt_path/.workmux.yaml"; do
    if [[ -f "$cf" ]]; then
        config_file="$cf"
        break
    fi
done

if [[ -n "$config_file" ]] && command -v python3 >/dev/null 2>&1; then
    hook_cmds=()
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && hook_cmds+=("$cmd")
    done < <(python3 -c "
import yaml
try:
    with open('$config_file', 'r') as f:
        data = yaml.safe_load(f) or {}
    hooks = data.get('hooks', {})
    cmds = hooks.get('pre-remove') or hooks.get('pre_remove') or []
    if isinstance(cmds, list):
        for c in cmds:
            if c: print(c)
    elif isinstance(cmds, str) and cmds.strip():
        print(cmds.strip())
except Exception:
    pass
" 2>/dev/null)

    for cmd in "${hook_cmds[@]}"; do
        if ! (cd "$wt_path" && eval "$cmd"); then
            echo "pre-remove hook command failed: $cmd" >&2
            exit 1
        fi
    done
fi

exit 0
