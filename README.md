# AI Sandbox

A containerized environment for running AI coding tools (Claude Code, OpenCode) with access to your local development setup.

## Build

```bash
docker build -t ai-sandbox .
```

## Run

```bash
docker run -d --name ai-sandbox \
  --read-only \
  --tmpfs /tmp \
  -v nix-store:/nix \
  -v "$HOME/dev/govapp:$HOME/dev/govapp" \
  -v "$HOME/.claude:/root/.claude" \
  -v "$HOME/.claude.json:/root/.claude.json" \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  -v "$HOME/.kube:/root/.kube:ro" \
  -v "$SSH_AUTH_SOCK:/tmp/ssh-agent.sock" \
  -e SSH_AUTH_SOCK=/tmp/ssh-agent.sock \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -w "$HOME/dev/govapp" \
  ai-sandbox
```

## Enter the container

```bash
docker exec -it ai-sandbox bash
```

## Run Claude Code

```bash
docker exec -it ai-sandbox claude-sandbox
```

## Notes

- **Docker rootless**: The container runs as root, which maps to your unprivileged host user in Docker rootless mode — no privilege escalation.
- **Read-only filesystem**: The root filesystem is read-only. `/tmp` is a writable tmpfs, and `/nix` uses a named volume to persist the Nix store across restarts.
- **Git worktrees**: The workspace is mounted at its host path so absolute paths in `.git` worktree files resolve correctly.
- **OAuth (Claude Max)**: Credentials are shared via the `~/.claude` and `~/.claude.json` mounts. No API key needed.
- **SSH agent forwarding**: The host's SSH agent socket is mounted into the container, so `git push` over SSH works without copying private keys. Ensure `ssh-agent` is running and your key is added (`ssh-add`) before starting the container.
- **GitHub token**: Create a fine-grained personal access token at https://github.com/settings/tokens?type=beta with at least Contents (read), Issues (read/write), Pull requests (read/write), and Metadata (read) permissions.
