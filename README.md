# multica-docker-env

Docker images for [Multica](https://github.com/multica/multica) agent daemons — one **tagged image per AI CLI**.

| Image | `Dockerfile.agent` target | Agent CLI |
|-------|---------------------------|-----------|
| `ghcr.io/sapk/multica-agent-claude` | `claude` | [Claude Code](https://claude.ai/code) |
| `ghcr.io/sapk/multica-agent-cursor` | `cursor` | [Cursor CLI](https://cursor.com) |
| `ghcr.io/sapk/multica-agent-opencode` | `opencode` | [OpenCode](https://opencode.ai) |
| `ghcr.io/sapk/multica-agent-codex` | `codex` | [OpenAI Codex CLI](https://developers.openai.com/codex/cli) |
| `ghcr.io/sapk/multica-agent-agy` | `agy` | [Antigravity CLI](https://antigravity.google/docs/cli-getting-started) |

Shared layers live in the `base` stage (multica CLI from the official backend image, Podman, nvm, pnpm, the Go toolchain, `glab`, entrypoint). Each variant adds its CLI.

The base also ships a C toolchain (`gcc` + `libc6-dev`) so cgo-dependent Go builds work out of the box — in particular `go test -race`, which requires `CGO_ENABLED=1` and a linker against the C runtime.

It also ships [`git-flow`](https://github.com/petervanderdoes/gitflow-avh) (the Debian `git-flow` package, AVH edition) so agents can run git-flow release/hotfix workflows without an extra install step.

[Playwright](https://playwright.dev/) is pre-installed with Chromium browser binary, along with the system libraries (X11, NSS, ATK, Pango, GBM, fonts) it needs to run headless. Agents running webapp E2E tests skip the `playwright install-deps` and `playwright install` steps entirely — browsers are ready to use immediately. Firefox and WebKit can be installed at runtime with `playwright install firefox webkit` if needed.

## Pull images

Published by CI to [GitHub Container Registry](https://github.com/sapk?tab=packages) (`ghcr.io/sapk/…`).

```bash
docker pull ghcr.io/sapk/multica-agent-claude:latest
docker pull ghcr.io/sapk/multica-agent-cursor:latest
docker pull ghcr.io/sapk/multica-agent-opencode:latest
docker pull ghcr.io/sapk/multica-agent-codex:latest
docker pull ghcr.io/sapk/multica-agent-agy:latest
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
| `UV_VERSION` | `0.11.23` | [`uv`](https://github.com/astral-sh/uv) release tag (used by `uv tool install` to install `mcp-proxy`) |
| `MCP_PROXY_VERSION` | `v0.12.0` | [`mcp-proxy`](https://github.com/sparfenyuk/mcp-proxy) release tag (stdio↔SSE/Streamable-HTTP bridge) |
| `GLAB_VERSION` | `1.107.0` | [`glab`](https://gitlab.com/gitlab-org/cli) release tag (GitLab CLI) |
| `PLAYWRIGHT_VERSION` | `1.52.0` | [`@playwright/test`](https://playwright.dev) release tag (browser E2E testing; pre-installs Chromium only) |

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

### Staging builds

`.github/workflows/staging-build.yml` builds the backend, web frontend, and all agent images from [`sapk-fork/multica`](https://github.com/sapk-fork/multica) `features/staging`:

| Trigger | Tags (per variant) |
|---------|-------------------|
| `repository_dispatch` (`staging-push`) | `staging`, `staging-sha-<commit>` |
| `workflow_dispatch` (manual) | `staging`, `staging-sha-<commit>` |

The backend image is also published as `ghcr.io/sapk/multica-backend:staging`.
The web frontend is also published as `ghcr.io/sapk/multica-web:staging`.

To trigger from a workflow in `sapk-fork/multica`:

```yaml
- uses: peter-evans/repository-dispatch@v3
  with:
    repository: sapk/multica-docker-env
    token: ${{ secrets.DISPATCH_TOKEN }}
    event-type: staging-push
    client-payload: '{"ref": "features/staging"}'
```

## License

MIT for files in this repo. The `multica` binary is part of [Multica](https://github.com/multica/multica) — see its [LICENSE](https://github.com/multica/multica/blob/main/LICENSE).
