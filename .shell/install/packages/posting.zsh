if ! pkg_is_installed posting; then
  # If uv is available, install isolated CLI tool via uv
  if command -v uv &>/dev/null; then
    uv tool install posting || true
  fi

  # Fallback to system package manager if not yet installed
  if ! command -v posting &>/dev/null; then
    if command -v yay &>/dev/null; then
      pkg_install posting
    fi
  fi
fi
