#!/usr/bin/env bash
# Matchmaker / Waymaker Agent Worktree Lifecycle Hook: pre-remove
# Args: <worktree_path> <branch_name>

wt_path="$1"
branch_name="$2"

[ -d "$wt_path" ] || exit 0

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
    done < <(awt_extract_config "$config_file" "hooks.pre-remove")

    for cmd in "${hook_cmds[@]}"; do
        if ! (cd "$wt_path" && eval "$cmd"); then
            echo "pre-remove hook command failed: $cmd" >&2
            exit 1
        fi
    done
fi

exit 0
