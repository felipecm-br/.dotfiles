#!/usr/bin/env bash
# Matchmaker / Waymaker Agent Worktree Lifecycle Hook: pre-merge
# Args: <worktree_path> <source_branch> <target_branch>

wt_path="$1"
source_branch="$2"
target_branch="$3"

[ -d "$wt_path" ] || exit 0

repo_parent=$(basename "$(dirname "$wt_path")")

# 1. Project-level custom script hooks (if defined in repository)
if [[ -x "$wt_path/.hooks/pre-merge" ]]; then
    "$wt_path/.hooks/pre-merge" "$wt_path" "$source_branch" "$target_branch"
    exit $?
elif [[ -x "$wt_path/.awt/hooks/pre-merge" ]]; then
    "$wt_path/.awt/hooks/pre-merge" "$wt_path" "$source_branch" "$target_branch"
    exit $?
elif [[ -x "$wt_path/.git/hooks/pre-worktree-merge" ]]; then
    "$wt_path/.git/hooks/pre-worktree-merge" "$wt_path" "$source_branch" "$target_branch"
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
    cmds = hooks.get('pre-merge') or hooks.get('pre_merge') or []
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
            echo "pre-merge hook command failed: $cmd" >&2
            exit 1
        fi
    done
fi

# 3. Automated Repository Quality Gate Checks
# If merging in .dotfiles, enforce docs and link integrity
if [[ "$repo_parent" == ".dotfiles" ]]; then
    if [[ -x "$wt_path/scripts/docs-lint.sh" ]]; then
        (cd "$wt_path" && ./scripts/docs-lint.sh >/dev/null 2>&1) || {
            echo "pre-merge check failed: ./scripts/docs-lint.sh detected broken links or misplaced root docs." >&2
            exit 1
        }
    fi
fi

exit 0
