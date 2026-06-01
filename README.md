# multica-docker-env

Docker images for [Multica](https://github.com/multica/multica) agent daemons — one **tagged image per AI CLI**.

| Image | `Dockerfile.agent` target | Agent CLI |
|-------|---------------------------|-----------|
| `ghcr.io/sapk/multica-agent-claude` | `claude` | [Claude Code](https://claude.ai/code) |
| `ghcr.io/sapk/multica-agent-cursor` | `cursor` | [Cursor CLI](https://cursor.com) |
| `ghcr.io/sapk/multica-agent-opencode` | `opencode` | [OpenCode](https://opencode.ai) |

Shared layers live in the `base` stage (multica CLI from the official backend image, Podman, nvm, pnpm, entrypoint). Each variant adds its CLI.

## Pull images

Published by CI to [GitHub Container Registry](https://github.com/sapk?tab=packages) (`ghcr.io/sapk/…`).

```bash
docker pull ghcr.io/sapk/multica-agent-claude:latest
docker pull ghcr.io/sapk/multica-agent-cursor:latest
docker pull ghcr.io/sapk/multica-agent-opencode:latest
```

Pin a daily snapshot or release:

```bash
docker pull ghcr.io/sapk/multica-agent-claude:2026-06-01
docker pull ghcr.io/sapk/multica-agent-claude:1.0.0   # after git tag v1.0.0
docker pull ghcr.io/sapk/multica-agent-claude:sha-a248603
```

**Browse tags:** open the package page for each variant (e.g. [multica-agent-claude](https://github.com/users/sapk/packages/container/multica-agent-claude)) or run:

```bash
gh api user/packages/container/multica-agent-claude/versions \
  --jq '.[].metadata.container.tags[]' | sort -u
```

If `docker pull` returns 404, the package may be private — make it public under **Package settings → Change visibility**, or `docker login ghcr.io`.

## Build locally

**All variants:**

```bash
make build-all
# → ghcr.io/sapk/multica-agent-claude:latest (local tag; not pushed)
```

**Single variant:**

```bash
make build-cursor IMAGE=ghcr.io/sapk/multica-agent TAG=local
```

**Plain `docker build`:**

```bash
docker build -f Dockerfile.agent --target claude \
  --build-arg MULTICA_TAG=v0.1.12 \
  -t ghcr.io/sapk/multica-agent-claude:local \
  .
```

Pin `MULTICA_TAG` to the same release as your Multica backend so the daemon CLI matches the server.

**Base only** (no AI CLI — debugging or custom downstream images):

```bash
docker build -f Dockerfile.agent --target base -t multica-agent-base:local .
```

## Makefile variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `IMAGE` | `ghcr.io/sapk/multica-agent` | Image name prefix (variant appended: `-claude`, etc.) |
| `TAG` | `latest` | Local image tag |
| `MULTICA_IMAGE` | `ghcr.io/multica-ai/multica-backend` | Source of `/app/multica` |
| `MULTICA_TAG` | `latest` | Backend image tag |

## Dockerfile build args

| Build arg | Default | Purpose |
|-----------|---------|---------|
| `USER_UID` / `USER_GID` | `1000` | Container user (`agent`) |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | placeholder | Baked `.gitconfig` |
| `NVM_VERSION` | `master` | nvm ref (`master` = rolling; pin e.g. `0.40.4`) |
| `NODE_VERSION` | `node` | Node via nvm (`node` = latest; pin e.g. `24.15.0`) |

Pass through `docker build --build-arg` or extend the `Makefile` `BUILD_ARGS` as needed.

## CI

GitHub Actions (`.github/workflows/docker.yml`) builds and pushes to GHCR:

| Trigger | Tags (per variant) |
|---------|-------------------|
| Push to `main` | `latest`, `sha-<commit>` |
| Git tag `v*.*.*` | `1.2.3`, `1.2`, `latest`, `sha-…` |
| **Daily 06:00 UTC** | `latest`, `YYYY-MM-DD` |
| Pull request | Build only (no push) |

Workflow runs: https://github.com/sapk/multica-docker-env/actions

## License

MIT for files in this repo. The `multica` binary is part of [Multica](https://github.com/multica/multica) — see its [LICENSE](https://github.com/multica/multica/blob/main/LICENSE).
