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

# rtk is opt-in and the switch is two-way: ENABLE_RTK=true installs it, and any
# other value (false, unset, "True", "1", ...) removes what a previous boot
# installed. Without the disable path, flipping the flag back off left the
# artifacts on disk and rtk stayed active — the flag only ever added.
if command -v rtk >/dev/null 2>&1; then
    # Resolve the agent variant once, so the enable and the disable path can
    # never target different integrations. Order matters and is unchanged: it
    # is the priority order the image variants were declared in.
    RTK_LABEL="" RTK_INIT_ARGS=()
    if   [ -n "${MULTICA_CLAUDE_PATH}" ];      then RTK_LABEL="claude";      RTK_INIT_ARGS=( -g )
    elif [ -n "${MULTICA_CURSOR_PATH}" ];      then RTK_LABEL="cursor";      RTK_INIT_ARGS=( -g --agent cursor )
    elif [ -n "${MULTICA_CODEX_PATH}" ];       then RTK_LABEL="codex";       RTK_INIT_ARGS=( -g --codex )
    elif [ -n "${MULTICA_OPENCODE_PATH}" ];    then RTK_LABEL="opencode";    RTK_INIT_ARGS=( -g --opencode )
    # antigravity does not support -g (no global workspace config)
    elif [ -n "${MULTICA_ANTIGRAVITY_PATH}" ]; then RTK_LABEL="antigravity"; RTK_INIT_ARGS=( --agent antigravity )
    fi

    if [ -z "${RTK_LABEL}" ]; then
        echo "[entrypoint] No MULTICA_*_PATH set — skipping rtk (ENABLE_RTK=${ENABLE_RTK:-<unset>})."
    elif [ "${ENABLE_RTK}" = "true" ]; then
        ( rtk init "${RTK_INIT_ARGS[@]}" ) || echo "[entrypoint] RTK init failed for ${RTK_LABEL}."
    else
        # Idempotent: rtk reports "nothing to remove" and exits 0 when clean.
        ( rtk init "${RTK_INIT_ARGS[@]}" --uninstall ) || echo "[entrypoint] RTK uninstall failed for ${RTK_LABEL}."
    fi
fi

exec "$@"
