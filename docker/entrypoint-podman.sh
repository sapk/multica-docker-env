#!/bin/bash
set -e

# Load nvm for agent shells (see https://github.com/nvm-sh/nvm#installing-in-docker-for-cicd-jobs)
if [ -s "${NVM_DIR:-}/nvm.sh" ]; then
  # shellcheck source=/dev/null
  . "${NVM_DIR}/nvm.sh"
fi

# Start podman Docker-compatible API service in the background
nohup podman system service --time=0 "${DOCKER_HOST}" > /tmp/podman-service.log 2>&1 &

echo "[entrypoint] Waiting for Docker daemon..."
for i in $(seq 1 30); do
    if [ -S "${DOCKER_HOST#unix://}" ]; then
        echo "[entrypoint] Docker socket ready after ${i}s."
        break
    fi
    sleep 1
done

if [ ! -S "${DOCKER_HOST#unix://}" ]; then
    echo "[entrypoint] Podman API failed to start within 30s." >&2
    cat /tmp/podman-service.log >&2 || true
fi

if [ "${ENABLE_RTK}" = "true" ] && command -v rtk >/dev/null 2>&1; then
    if   [ -n "${MULTICA_CLAUDE_PATH}" ];      then ( rtk init -g )                     || echo "[entrypoint] RTK init failed for claude."
    elif [ -n "${MULTICA_CURSOR_PATH}" ];      then ( rtk init -g --agent cursor )      || echo "[entrypoint] RTK init failed for cursor."
    elif [ -n "${MULTICA_CODEX_PATH}" ];       then ( rtk init -g --codex )             || echo "[entrypoint] RTK init failed for codex."
    elif [ -n "${MULTICA_OPENCODE_PATH}" ];    then ( rtk init -g --opencode )          || echo "[entrypoint] RTK init failed for opencode."
    # antigravity does not support -g (no global workspace config)
    elif [ -n "${MULTICA_ANTIGRAVITY_PATH}" ]; then ( rtk init --agent antigravity )    || echo "[entrypoint] RTK init failed for antigravity."
    fi
fi

exec "$@"
