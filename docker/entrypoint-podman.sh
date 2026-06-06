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

if [ "${ENABLE_RTK}" = "true" ] && [ -n "${MULTICA_AGENT_TYPE}" ] && command -v rtk >/dev/null 2>&1; then
    echo "[entrypoint] Initializing RTK for agent: ${MULTICA_AGENT_TYPE}"
    case "${MULTICA_AGENT_TYPE}" in
        claude)       rtk init -g --agent claude ;;
        cursor)       rtk init -g --agent cursor ;;
        gemini)       rtk init -g --gemini ;;
        codex)        rtk init -g --codex ;;
        opencode)     rtk init -g --opencode ;;
        antigravity)  rtk init --agent antigravity ;;
        *)            echo "[entrypoint] Unknown agent type for RTK: ${MULTICA_AGENT_TYPE}" ;;
    esac
fi

exec "$@"
