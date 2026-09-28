# multica-docker-env

Docker images for [Multica](https://github.com/multica/multica) agent daemons — one **tagged image per AI CLI**.

| Image | `Dockerfile.agent` target | Agent CLI |
|-------|---------------------------|-----------|
| `ghcr.io/sapk/multica-agent-claude` | `claude` | [Claude Code](https://claude.ai/code) |
| `ghcr.io/sapk/multica-agent-cursor` | `cursor` | [Cursor CLI](https://cursor.com) |
| `ghcr.io/sapk/multica-agent-opencode` | `opencode` | [OpenCode](https://opencode.ai) 1.x |
| `ghcr.io/sapk/multica-agent-opencode-v2` | `opencode-v2` | [OpenCode](https://opencode.ai) 2.x — see the caveat below |
| `ghcr.io/sapk/multica-agent-codex` | `codex` | [OpenAI Codex CLI](https://developers.openai.com/codex/cli) |
| `ghcr.io/sapk/multica-agent-kimi` | `kimi` | [Kimi Code CLI](https://github.com/MoonshotAI/kimi-code) |
| `ghcr.io/sapk/multica-agent-agy` | `agy` | [Antigravity CLI](https://antigravity.google/docs/cli-getting-started) |

Shared layers live in the `base` stage (multica CLI from the official backend image, Podman, nvm, pnpm, the Go toolchain, `glab`, entrypoint). Each variant adds its CLI.

The base also ships a C toolchain (`gcc` + `libc6-dev`) so cgo-dependent Go builds work out of the box — in particular `go test -race`, which requires `CGO_ENABLED=1` and a linker against the C runtime.

It also ships [`git-flow`](https://github.com/petervanderdoes/gitflow-avh) (the Debian `git-flow` package, AVH edition) so agents can run git-flow release/hotfix workflows without an extra install step.

The base image includes [DuckDB](https://duckdb.org/) CLI for querying CSV, Parquet, JSON, SQLite, and other data sources directly from the command line.

The base image includes [`age`](https://github.com/FiloSottile/age) and [`sops`](https://github.com/getsops/sops) for encrypting/decrypting secrets files (e.g. `.sops.yaml`-managed YAML/JSON/ENV secrets), so agents can work with encrypted config without an extra install step.

The base image pre-installs Playwright browser binaries (Chromium, Firefox, WebKit) with a 5-minute timeout. System libraries for headless browsing (X11, NSS, ATK, Pango, GBM, fonts) are also included. If the installation times out during build, the build fails fast with diagnostics (memory, disk space). To adjust the timeout, pass `--build-arg PLAYWRIGHT_TIMEOUT=600` (seconds). Browsers are installed to `$PLAYWRIGHT_BROWSERS_PATH` (`~/.cache/ms-playwright` by default).

## Pull images

Published by CI to [GitHub Container Registry](https://github.com/sapk?tab=packages) (`ghcr.io/sapk/…`).

```bash
docker pull ghcr.io/sapk/multica-agent-claude:latest
docker pull ghcr.io/sapk/multica-agent-cursor:latest
docker pull ghcr.io/sapk/multica-agent-opencode:latest
docker pull ghcr.io/sapk/multica-agent-opencode-v2:latest
docker pull ghcr.io/sapk/multica-agent-codex:latest
docker pull ghcr.io/sapk/multica-agent-kimi:latest
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

## OpenCode: two variants, 1.x and 2.x

`multica-agent-opencode` is **OpenCode 1.x** and stays the default. `multica-agent-opencode-v2` is
**OpenCode 2.x**. They are separate images because the two lines are genuinely independent:

| | Install channel | Binary lands in |
|---|---|---|
| `opencode` (1.x) | `curl -fsSL https://opencode.ai/install` | `~/.opencode/bin/opencode` |
| `opencode-v2` (2.x) | npm `@opencode/cli` | `~/.local/node-active/opencode` |

The installer script's `releases/latest` is the 1.x channel, and 2.x publishes no release assets at
all — so 2.x is only reachable from npm. Both versions are **pinned** via `OPENCODE_VERSION` and
`OPENCODE_V2_VERSION` rather than floating. That matters more than usual here: the daemon chooses
the CLI's argv from the binary's `--version` string, not from the image name, so a silent upstream
major bump would change the contract every task runs under with no commit and no review. The
`opencode-v2` build additionally asserts the `opencode v2.x` version shape and fails the build
otherwise.

Verify either image before rolling it out. Use the absolute path: on the v1 image `opencode` is
**not** on `PATH` (the installer only appends it to `~/.bashrc`), so a bare `--entrypoint opencode`
fails there while succeeding on v2.

```bash
docker run --rm --entrypoint /home/agent/.opencode/bin/opencode ghcr.io/sapk/multica-agent-opencode:latest --version       # 1.18.32
docker run --rm --entrypoint /home/agent/.local/node-active/opencode ghcr.io/sapk/multica-agent-opencode-v2:latest --version  # opencode v2.0.18
```

### 2.x cannot use Multica-managed MCP servers

**Use the v1 image for any runtime that relies on Multica-managed MCP servers.** OpenCode 2.x honours
no environment-based config channel — it only reads `<workdir>/opencode.json`, and its MCP entries
carry bearer headers and OAuth secrets that the agent's own commits would capture. Rather than write
those secrets to disk, the daemon refuses runs that carry MCP config on a 2.x runtime
(`ErrOpenCodeV2MCPUnsupported`, `server/pkg/agent/opencode_v2.go`), naming every MCP source in the
error.

Pick `opencode-v2` only for single-agent setups that do not use Multica-managed MCP, until MCP
delivery is restored.

### RTK on 2.x

`rtk init -g --opencode` (run from `docker/entrypoint-podman.sh` when `ENABLE_RTK=true`) keys on
`MULTICA_OPENCODE_PATH`, so it fires on both images and writes the plugin to
`~/.config/opencode/plugins/rtk.ts`, which 2.x documents as an auto-loaded global plugin directory.
`ENABLE_RTK` is two-way: any value other than the exact string `true` — `false`, unset, `True`, `1` —
runs the same command with `--uninstall`, so clearing the flag removes the artifacts a previous boot
installed instead of leaving them in place. `--uninstall` is idempotent (it reports "nothing to
remove" and exits 0 when already clean) and is present in `v0.46.0` (the pinned version) and
`v0.50.0`.
The generated plugin type-imports `@opencode-ai/plugin`; that is a type-only import, so it is erased
at compile time and is not itself a risk. What is **unverified** is whether the rewrite hook actually
fires on 2.x — a 2.x server here reported zero loaded plugins under every configuration tried.

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
| `OPENCODE_VERSION` | `1.18.32` | OpenCode 1.x release, for the `opencode` target |
| `OPENCODE_V2_VERSION` | `2.0.18` | [`@opencode/cli`](https://www.npmjs.com/package/@opencode/cli) version, for the `opencode-v2` target |
| `PLAYWRIGHT_VERSION` | `1.62.1` | [`@playwright/test`](https://playwright.dev/) version (coupled to the system-library list in `Dockerfile.agent`) |
| `GO_VERSION` | `1.27.0` | [Go](https://go.dev/dl/) toolchain release |
| `GOLANGCI_LINT_VERSION` | `v2.13.2` | [`golangci-lint`](https://github.com/golangci/golangci-lint) release tag (Go static analysis) |
| `RTK_VERSION` | `v0.46.0` | [`rtk`](https://github.com/rtk-ai/rtk) release tag (token-optimised CLI proxy) |
| `UV_VERSION` | `0.12.8` | [`uv`](https://github.com/astral-sh/uv) release tag (used by `uv tool install` to install `mcp-proxy`) |
| `MCP_PROXY_VERSION` | `v0.12.0` | [`mcp-proxy`](https://github.com/sparfenyuk/mcp-proxy) release tag (stdio↔SSE/Streamable-HTTP bridge) |
| `GLAB_VERSION` | `1.115.0` | [`glab`](https://gitlab.com/gitlab-org/cli) release tag (GitLab CLI) |
| `DUCKDB_VERSION` | `v1.5.5` | [`DuckDB`](https://duckdb.org/) release tag (in-process SQL OLAP CLI) |
| `AGE_VERSION` | `v1.3.2` | [`age`](https://github.com/FiloSottile/age) release tag (file encryption tool) |
| `SOPS_VERSION` | `v3.13.3` | [`sops`](https://github.com/getsops/sops) release tag (secrets file encryption CLI) |
| `PLAYWRIGHT_TIMEOUT` | `300` | Seconds before Playwright browser install fails (timeout wrapper) |

These are `docker build --build-arg` arguments. **`make` does not forward them** — the Makefile's
`VARIANT_ARGS` passes only `MULTICA_IMAGE`, `MULTICA_TAG`, and `AGENT_BASE_IMAGE`, so
`make build-opencode-v2 OPENCODE_V2_VERSION=…` is a silent no-op that builds the default. Bump a pin
with `docker build`, or add it to `VARIANT_ARGS` in the `Makefile`.

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
