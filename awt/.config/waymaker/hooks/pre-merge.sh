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

# Helper: stamp test status trailer onto HEAD commit if not already present
awt_stamp_test_trailer() {
    local wt="$1"
    local status_label="$2"

    local head_msg
    head_msg=$(git -C "$wt" log -1 --format=%B 2>/dev/null || true)
    [[ -z "$head_msg" ]] && return 0

    if echo "$head_msg" | grep -Ei -q '^(test|tests|test-status|ci):'; then
        return 0
    fi

    if git -C "$wt" diff --quiet 2>/dev/null && git -C "$wt" diff --cached --quiet 2>/dev/null; then
        git -C "$wt" commit --amend --no-edit --trailer "Test-Status: $status_label" >/dev/null 2>&1 || true
        echo "Stamped 'Test-Status: $status_label' on commit $(git -C "$wt" rev-parse --short HEAD 2>/dev/null)."
    fi
}

# 3. Automated Repository Quality Gate Checks
# If merging in .dotfiles, enforce docs and link integrity
if [[ "$repo_parent" == ".dotfiles" ]]; then
    if [[ -x "$wt_path/scripts/docs-lint.sh" ]]; then
        (cd "$wt_path" && ./scripts/docs-lint.sh >/dev/null 2>&1) || {
            echo "pre-merge check failed: ./scripts/docs-lint.sh detected broken links or misplaced root docs." >&2
            exit 1
        }
        awt_stamp_test_trailer "$wt_path" "pass (docs-lint)"
    fi
fi

# If repository defines 'just check', enforce it
if [[ -f "$wt_path/Justfile" ]] || [[ -f "$wt_path/justfile" ]]; then
    if command -v just >/dev/null 2>&1 && (cd "$wt_path" && just --summary 2>/dev/null | grep -qw "check"); then
        echo "Running pre-merge quality gate: 'just check' in $(basename "$wt_path")..."
        if (cd "$wt_path" && just check); then
            awt_stamp_test_trailer "$wt_path" "pass (just check)"
        else
            echo "pre-merge check failed: 'just check' reported errors." >&2
            exit 1
        fi
    fi
elif [[ -f "$wt_path/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
    echo "Running pre-merge quality gate: 'cargo test' in $(basename "$wt_path")..."
    test_out=$(cd "$wt_path" && cargo test 2>&1)
    test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
        passed_count=$(echo "$test_out" | grep -E "test result: ok\." | sed -E 's/.*ok\.[[:space:]]*([0-9]+)[[:space:]]*passed.*/\1/' | head -n1)
        if [[ -n "$passed_count" && "$passed_count" =~ ^[0-9]+$ ]]; then
            awt_stamp_test_trailer "$wt_path" "pass ($passed_count/$passed_count)"
        else
            awt_stamp_test_trailer "$wt_path" "pass (cargo test)"
        fi
    else
        echo "pre-merge check failed: 'cargo test' reported errors:" >&2
        echo "$test_out" | tail -n 20 >&2
        exit 1
    fi
fi

exit 0
