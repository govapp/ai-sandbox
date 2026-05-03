# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository builds and publishes a Docker container image that provides a sandboxed environment for running AI coding tools (Claude Code, OpenCode). The image is published to `ghcr.io/govapp/ai-sandbox` via GitHub Actions on every push to `main`.

## Build Commands

```bash
# Build Docker image from source
docker build -t ai-sandbox .

# Pull published image
docker pull ghcr.io/govapp/ai-sandbox:latest
```

There are no lint or test commands — validation is done by building and running the container.

## Architecture

The project has three main files:

- **`Dockerfile`** — Multi-stage build on `nixos/nix` base. Installs all packages from `flake.nix`, configures fontconfig for headless Chromium, sets `IS_SANDBOX=1`, and pre-creates credential directories.
- **`flake.nix`** — Nix flake declaring all installed packages (gh, ripgrep, chromium, claude-code, opencode, fonts, etc.) and defines a `claude-sandbox` wrapper script that sets Claude's permission mode and allowed tools.
- **`entrypoint.sh`** — Bootstraps direnv (moves its data dirs to `/tmp` due to read-only root), whitelists `/workspace` and `/home` in direnv, and loads `.envrc` from the workspace.

## Key Design Constraints

- **Read-only root filesystem** (`--read-only`): Only `/tmp` (tmpfs) and `/nix` (named volume) are writable. Any new files created during the build must land in `/tmp` or `/nix`, not the root FS.
- **No API key required**: Claude Code authenticates via OAuth — credentials shared via `~/.claude` and `~/.claude.json` volume mounts.
- **SSH agent forwarding**: The host SSH agent socket is mounted at `/tmp/ssh-agent.sock`. Private keys are never copied into the image.
- **Git worktree path preservation**: The workspace is mounted at its exact host path so absolute paths in `.git` worktree pointer files resolve correctly inside the container.
- **`--shm-size=2g`**: Required for headless Chromium (shared memory for renderer processes).

## Claude Code Auto-Update

Claude Code updates are applied at container startup without rebuilding the image:

- `entrypoint.sh` checks `/nix/.claude-last-update` (epoch timestamp in the `/nix` named volume)
- If older than 24 hours, runs `nix profile install/upgrade` in the **background** against `github:numtide/llm-agents.nix`
- The updated binary lands in `/nix/var/nix/profiles/claude-update/bin/` (persistent across restarts)
- `PATH` is prepended with that directory so the updated binary shadows the baked-in one

First container start: baked-in binary is used while the background install runs. Second start: updated binary is active. Update log: `/tmp/claude-update.log` (ephemeral, per container session).

The weekly GitHub Actions schedule (`scheduled-rebuild.yml`, Sundays 02:00 UTC) rebuilds the image with `no-cache: true` to keep non-claude tools (chromium, gh, etc.) fresh.

## Claude Code Permissions

Configured in `.claude/settings.local.json`:
- Allowed: `WebFetch` (github.com domains), `Bash` with selected commands
- Denied: `sudo`, `su`, `rm -rf /`

The `claude-sandbox` wrapper in `flake.nix` sets `--permission-mode default` and explicitly lists allowed tools.

## CI/CD

`.github/workflows/build-image.yml` runs on push to `main` and publishes two tags: `:latest` and `:<git-sha>` to `ghcr.io/govapp/ai-sandbox`.
