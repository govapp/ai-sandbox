#!/usr/bin/env bash
set -e

# --- Claude Code auto-update ---
# Installs/upgrades claude-code into a dedicated nix profile stored in the
# persistent /nix volume, so updates survive container restarts without
# requiring a new Docker image build.
_CLAUDE_PROFILE=/nix/var/nix/profiles/claude-update
_CLAUDE_TS=/nix/.claude-last-update
_UPDATE_INTERVAL=$((24 * 60 * 60))

# Prepend the dedicated profile bin dir so the updated binary shadows the
# baked-in one. No-op PATH-wise if the profile doesn't exist yet.
export PATH="${_CLAUDE_PROFILE}/bin:${PATH}"

_claude_needs_update() {
  [ ! -f "$_CLAUDE_TS" ] && return 0
  local age=$(( $(date +%s) - $(cat "$_CLAUDE_TS") ))
  [ "$age" -ge "$_UPDATE_INTERVAL" ]
}

_claude_update() {
  if [ ! -e "$_CLAUDE_PROFILE" ]; then
    # First run: install from the remote flake URL so future upgrades work.
    nix profile install \
      --profile "$_CLAUDE_PROFILE" \
      --accept-flake-config \
      'github:numtide/llm-agents.nix#claude-code' \
      'github:numtide/llm-agents.nix#claude-plugins' \
      >/tmp/claude-update.log 2>&1
  else
    # Subsequent runs: upgrade in place (uses the stored github: URL).
    nix profile upgrade \
      --profile "$_CLAUDE_PROFILE" \
      --accept-flake-config \
      '.*' \
      >/tmp/claude-update.log 2>&1
  fi && date +%s > "$_CLAUDE_TS"
}

if _claude_needs_update; then
  ( _claude_update ) &
  disown
fi
# --- end auto-update ---

# agent-browser's home (~/.agent-browser, symlinked to here in the image) holds
# its daemon socket/state and the Chromium user-data-dir. Create it on tmpfs so
# the read-only root doesn't block browser launches.
mkdir -p /tmp/agent-browser

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
