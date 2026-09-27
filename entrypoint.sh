#!/usr/bin/env bash
set -e

# No runtime claude-code auto-update. There was one here; it was removed
# because it cost ~435 MB per container and never took effect. Both halves
# were measured on this image, so don't reinstate it without re-reading these:
#
#  1. It installed into /nix/var/nix/profiles/claude-update "stored in the
#     persistent /nix volume". There is no /nix volume — dons-claude mounts
#     only the repo, host /tmp, and credentials, so /nix (and the
#     /nix/.claude-last-update guard) lives in the container's writable
#     overlay. Every newly created container therefore found no timestamp and
#     re-fetched claude-code plus its source paths into a layer that is
#     discarded with the container.
#  2. It was never on the PATH that matters. This entrypoint wraps PID 1
#     (`sleep infinity`); Claude sessions arrive later over
#     `docker exec ... bash -l -c`, which takes PATH from the image ENV and
#     /root/.bashrc, neither of which mentions the profile. Sessions ran the
#     baked-in claude-code from /root/.nix-profile while the fetched copy sat
#     unused. Verified across three live containers: exec resolved 2.1.278
#     while the updater had installed 2.1.283.
#
# claude-code is pinned in flake.nix (llm.claude-code) together with
# claude-plugins and the claude-sandbox wrapper, and
# .github/workflows/scheduled-rebuild.yml refreshes flake.lock and rebuilds
# weekly. Bump the version there — shorten that cron if the image goes stale.
# A runtime updater would also have to reach exec sessions (Dockerfile ENV or
# /root/.bashrc) and would desync claude-code from the plugins and wrapper the
# flake pins alongside it.

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
