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

if [ "${ENABLE_HEADROOM}" = "true" ]; then
    echo "[entrypoint] ENABLE_HEADROOM=true, wrapping agent binaries with headroom..."
    WRAPPER_DIR="/tmp/headroom-wrappers"
    mkdir -p "${WRAPPER_DIR}"

    create_wrapper() {
        local agent_name="$1"
        local wrapper_path="${WRAPPER_DIR}/${agent_name}-hr"
        cat > "${wrapper_path}" <<EOF
#!/bin/bash
exec headroom wrap ${agent_name} "\$@"
EOF
        chmod +x "${wrapper_path}"
        echo "${wrapper_path}"
    }

    if [ -n "${MULTICA_CLAUDE_PATH:-}" ]; then
        export MULTICA_CLAUDE_PATH="$(create_wrapper claude)"
        echo "[entrypoint] Wrapped claude: ${MULTICA_CLAUDE_PATH}"
    fi

    if [ -n "${MULTICA_CURSOR_PATH:-}" ]; then
        export MULTICA_CURSOR_PATH="$(create_wrapper cursor)"
        echo "[entrypoint] Wrapped cursor: ${MULTICA_CURSOR_PATH}"
    fi

    if [ -n "${MULTICA_CODEX_PATH:-}" ]; then
        export MULTICA_CODEX_PATH="$(create_wrapper codex)"
        echo "[entrypoint] Wrapped codex: ${MULTICA_CODEX_PATH}"
    fi
fi

exec "$@"
