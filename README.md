# multica-docker-env

Docker images for [Multica](https://github.com/multica/multica) agent daemons — one **tagged image per AI CLI**.

| Image tag suffix | `Dockerfile.agent` target | Agent CLI |
|------------------|---------------------------|-----------|
| `-claude` | `claude` | [Claude Code](https://claude.ai/code) |
| `-cursor` | `cursor` | [Cursor CLI](https://cursor.com) |
| `-opencode` | `opencode` | [OpenCode](https://opencode.ai) |

Shared layers live in the `base` stage (multica CLI from the official backend image, Podman, nvm, pnpm, entrypoint). Each variant adds its CLI.

## Build

**All variants** (default registry prefix and tag):

```bash
make build-all
# → ghcr.io/multica-ai/multica-agent-claude:latest
# → ghcr.io/multica-ai/multica-agent-cursor:latest
# → ghcr.io/multica-ai/multica-agent-opencode:latest
```

**Single variant:**

```bash
make build-cursor IMAGE=myregistry/multica-agent TAG=v0.1.0
```

**Plain `docker build`:**

```bash
docker build -f Dockerfile.agent --target claude \
  --build-arg MULTICA_TAG=v0.1.12 \
  -t ghcr.io/multica-ai/multica-agent-claude:v0.1.12 \
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
| `IMAGE` | `ghcr.io/multica-ai/multica-agent` | Image name prefix (variant appended: `-claude`, etc.) |
| `TAG` | `latest` | Image tag |
| `MULTICA_IMAGE` | `ghcr.io/multica-ai/multica-backend` | Source of `/app/multica` |
| `MULTICA_TAG` | `latest` | Backend image tag |

## Dockerfile build args

| Build arg | Default | Purpose |
|-----------|---------|---------|
| `USER_UID` / `USER_GID` | `1000` | Container user |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | placeholder | Baked `.gitconfig` |
| `NVM_VERSION` | `master` | nvm ref (`master` = rolling; pin e.g. `0.40.4` → tag `v0.40.4`) |
| `NODE_VERSION` | `node` | nvm version (`node` = latest; pin e.g. `24.15.0`) |

Pass through `docker build --build-arg` or extend the `Makefile` `BUILD_ARGS` as needed.

## CI

GitHub Actions (`.github/workflows/docker.yml`) builds and pushes all three variants to GHCR:

| Trigger | Images |
|---------|--------|
| Push to `main` | `:latest` + `:sha-…` |
| Git tag `v*.*.*` | semver tags + `:latest` (stable releases) |
| **Daily 06:00 UTC** | Refreshes `:latest` and adds `:YYYY-MM-DD` (rolling upstream pins) |
| Pull request | Build only (no push) |

## License

MIT for files in this repo. The `multica` binary is part of [Multica](https://github.com/multica/multica) — see its [LICENSE](https://github.com/multica/multica/blob/main/LICENSE).
