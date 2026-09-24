#!/usr/bin/env bash
# Matchmaker Agent Worktree Lifecycle Hook: post-create
# Args: <worktree_path> <branch_name> <base_branch>

wt_path="$1"
branch_name="$2"
base_branch="$3"

[ -d "$wt_path" ] || exit 0

repo_root=$(git -C "$wt_path" rev-parse --show-toplevel 2>/dev/null || echo "$wt_path")
parent_dir="$(cd "$wt_path/.." 2>/dev/null && pwd || dirname "$wt_path")"

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

# 1. Hermetic Secret & Environment Propagation (.env, .env.local, .env.*.local)
primary_wt=""
while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.*) ]]; then
        wt_cand="${BASH_REMATCH[1]}"
        if [[ -d "$wt_cand" && "$wt_cand" != "$wt_path" ]]; then
            if [[ -z "$primary_wt" ]]; then
                primary_wt="$wt_cand"
            fi
            b=$(basename "$wt_cand")
            if [[ "$b" == "main" || "$b" == "master" ]]; then
                primary_wt="$wt_cand"
                break
            fi
        fi
    fi
done < <(git -C "$wt_path" worktree list --porcelain 2>/dev/null || true)

# Fallback paths if porcelain check yields empty
if [[ -z "$primary_wt" || ! -d "$primary_wt" ]]; then
    if [[ -d "$parent_dir/main" && "$parent_dir/main" != "$wt_path" ]]; then
        primary_wt="$parent_dir/main"
    elif [[ -d "$parent_dir/master" && "$parent_dir/master" != "$wt_path" ]]; then
        primary_wt="$parent_dir/master"
    elif [[ -d "$repo_root/../main" && "$repo_root/../main" != "$wt_path" ]]; then
        primary_wt="$repo_root/../main"
    elif [[ -d "$repo_root/../master" && "$repo_root/../master" != "$wt_path" ]]; then
        primary_wt="$repo_root/../master"
    fi
fi

if [[ -n "$primary_wt" && -d "$primary_wt" ]]; then
    # Propagate standard and local hermetic environment files
    env_targets=(".env" ".env.local" ".env.development.local" ".env.test.local" ".env.production.local")
    
    # Also discover any existing .env.*.local files in primary worktree (deduplicated)
    for extra_env in "$primary_wt"/.env.*.local; do
        if [[ -f "$extra_env" ]]; then
            b_env="$(basename "$extra_env")"
            already_tracked=0
            for existing in "${env_targets[@]}"; do
                if [[ "$existing" == "$b_env" ]]; then
                    already_tracked=1
                    break
                fi
            done
            [[ $already_tracked -eq 0 ]] && env_targets+=("$b_env")
        fi
    done

    for env_file in "${env_targets[@]}"; do
        src="$primary_wt/$env_file"
        dst="$wt_path/$env_file"
        if [[ -f "$src" && ! -f "$dst" ]]; then
            cp "$src" "$dst" 2>/dev/null || true
        fi
    done

    # Fallback to .env.example or .env.local.example if no .env exists
    if [[ ! -f "$wt_path/.env" ]]; then
        if [[ -f "$primary_wt/.env.example" ]]; then
            cp "$primary_wt/.env.example" "$wt_path/.env" 2>/dev/null || true
        elif [[ -f "$wt_path/.env.example" ]]; then
            cp "$wt_path/.env.example" "$wt_path/.env" 2>/dev/null || true
        elif [[ -f "$primary_wt/.env.local.example" ]]; then
            cp "$primary_wt/.env.local.example" "$wt_path/.env" 2>/dev/null || true
        elif [[ -f "$wt_path/.env.local.example" ]]; then
            cp "$wt_path/.env.local.example" "$wt_path/.env" 2>/dev/null || true
        fi
    fi

    # 2. Declarative File Copy & Symlink Synchronization (.awt.toml canonical / manifests / YAML fallback)
    config_file=""
    for cf in "$wt_path/.awt.toml" "$wt_path/.awt/config.toml" "$primary_wt/.awt.toml" "$primary_wt/.awt/config.toml" \
              "$wt_path/.awt.yaml" "$wt_path/.awt/config.yaml" "$wt_path/.workmux.yaml" \
              "$primary_wt/.awt.yaml" "$primary_wt/.workmux.yaml"; do
        if [[ -f "$cf" ]]; then
            config_file="$cf"
            break
        fi
    done

    # 2a. Declarative file copies
    copy_targets=()
    if [[ -n "$config_file" ]]; then
        while IFS= read -r item; do
            [[ -n "$item" ]] && copy_targets+=("$item")
        done < <(awt_extract_config "$config_file" "files.copy")
    fi

    for cf_txt in "$wt_path/.awt/files.copy" "$primary_wt/.awt/files.copy"; do
        if [[ -f "$cf_txt" ]]; then
            while IFS= read -r line; do
                line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/#.*//')"
                [[ -n "$line" ]] && copy_targets+=("$line")
            done < "$cf_txt"
            break
        fi
    done

    for item in "${copy_targets[@]}"; do
        src="$primary_wt/$item"
        dst="$wt_path/$item"
        if [[ -e "$src" && ! -e "$dst" ]]; then
            mkdir -p "$(dirname "$dst")" 2>/dev/null || true
            cp -a "$src" "$dst" 2>/dev/null || cp -R "$src" "$dst" 2>/dev/null || true
        fi
    done

    # 2b. Declarative symlinks (shared caches, large node_modules, build targets)
    symlink_targets=()
    if [[ -n "$config_file" ]]; then
        while IFS= read -r item; do
            [[ -n "$item" ]] && symlink_targets+=("$item")
        done < <(awt_extract_config "$config_file" "files.symlink")
    fi

    for sf_txt in "$wt_path/.awt/files.symlink" "$primary_wt/.awt/files.symlink"; do
        if [[ -f "$sf_txt" ]]; then
            while IFS= read -r line; do
                line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/#.*//')"
                [[ -n "$line" ]] && symlink_targets+=("$line")
            done < "$sf_txt"
            break
        fi
    done

    for item in "${symlink_targets[@]}"; do
        src="$primary_wt/$item"
        dst="$wt_path/$item"
        if [[ -e "$src" && ! -e "$dst" && ! -L "$dst" ]]; then
            mkdir -p "$(dirname "$dst")" 2>/dev/null || true
            ln -s "$src" "$dst" 2>/dev/null || true
        fi
    done
fi

# 3. Declarative Post-Create Lifecycle Hook Commands (.awt.toml / .workmux.yaml)
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
    done < <(awt_extract_config "$config_file" "hooks.post-create")

    for cmd in "${hook_cmds[@]}"; do
        (cd "$wt_path" && eval "$cmd") 2>/dev/null || true
    done
fi

# 4. Project-level custom script hooks (if defined in repository)
if [[ -x "$wt_path/.hooks/post-create" ]]; then
    "$wt_path/.hooks/post-create" "$wt_path" "$branch_name" "$base_branch"
elif [[ -x "$wt_path/.awt/hooks/post-create" ]]; then
    "$wt_path/.awt/hooks/post-create" "$wt_path" "$branch_name" "$base_branch"
elif [[ -x "$wt_path/.git/hooks/post-worktree-create" ]]; then
    "$wt_path/.git/hooks/post-worktree-create" "$wt_path" "$branch_name" "$base_branch"
fi
