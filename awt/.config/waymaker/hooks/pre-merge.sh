#!/usr/bin/env bash
# Matchmaker / Waymaker Agent Worktree Lifecycle Hook: pre-merge
# Args: <worktree_path> <source_branch> <target_branch>

wt_path="$1"
source_branch="$2"
target_branch="$3"

[ -d "$wt_path" ] || exit 0

repo_parent=$(basename "$(dirname "$wt_path")")

# Helper: parse declarative config key from .awt.toml (canonical) or YAML (fallback)
awt_extract_config() {
    local cfg="$1"
    local q="$2"
    [[ -f "$cfg" ]] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    python3 -c "
import sys

filepath = sys.argv[1]
query = sys.argv[2]
data = None

if filepath.endswith('.toml'):
    try:
        import tomllib
        with open(filepath, 'rb') as f:
            data = tomllib.load(f)
    except Exception:
        pass
elif filepath.endswith('.yaml') or filepath.endswith('.yml'):
    try:
        import yaml
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
    except Exception:
        pass

if isinstance(data, dict):
    val = data
    for k in query.split('.'):
        if isinstance(val, dict):
            val = val.get(k) or val.get(k.replace('-', '_'))
        else:
            val = None
            break
    if isinstance(val, list):
        for x in val:
            if x is not None:
                print(x)
    elif isinstance(val, str) and val.strip():
        print(val.strip())
" "$cfg" "$q" 2>/dev/null
}

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

# 2. Declarative hooks from .awt.toml (canonical) / .workmux.yaml
config_file=""
for cf in "$wt_path/.awt.toml" "$wt_path/.awt/config.toml" \
          "$wt_path/.awt.yaml" "$wt_path/.awt/config.yaml" "$wt_path/.workmux.yaml"; do
    if [[ -f "$cf" ]]; then
        config_file="$cf"
        break
    fi
done

if [[ -n "$config_file" ]]; then
    hook_cmds=()
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && hook_cmds+=("$cmd")
    done < <(awt_extract_config "$config_file" "hooks.pre-merge")

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

# If repository defines 'just check', enforce it
if [[ -f "$wt_path/Justfile" ]] || [[ -f "$wt_path/justfile" ]]; then
    if command -v just >/dev/null 2>&1 && (cd "$wt_path" && just --summary 2>/dev/null | grep -qw "check"); then
        echo "Running pre-merge quality gate: 'just check' in $(basename "$wt_path")..."
        (cd "$wt_path" && just check) || {
            echo "pre-merge check failed: 'just check' reported errors." >&2
            exit 1
        }
    fi
fi

exit 0
