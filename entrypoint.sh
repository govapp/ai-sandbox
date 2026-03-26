#!/usr/bin/env bash
set -e

# Set up direnv directories in a writable location
DIRENV_TMP="/tmp/direnv"
mkdir -p "${DIRENV_TMP}/config" "${DIRENV_TMP}/data"

# Write direnv config to whitelist /workspace
if [ ! -f "${DIRENV_TMP}/config/direnv.toml" ]; then
  echo '[whitelist]' > "${DIRENV_TMP}/config/direnv.toml"
  echo 'prefix = ["/workspace", "/home"]' >> "${DIRENV_TMP}/config/direnv.toml"
fi

export DIRENV_CONFIG="${DIRENV_TMP}/config"
export XDG_DATA_HOME="${DIRENV_TMP}/data"

# If /workspace has a .envrc, allow and load it
if [ -f /workspace/.envrc ]; then
  direnv allow /workspace
  eval "$(direnv export bash)"
fi

exec "$@"
