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

# rtk is opt-in via ENABLE_RTK, which has three explicit states:
#
#   true            install the variant this image ships
#   false|0|no|off  remove rtk from every variant
#   unset / other   no-op, reported in the log
#
# Only a positive off disables. Before this block, ENABLE_RTK was one-way: the
# single `if [ ... = "true" ]` had no else, so clearing it left every artifact a
# previous boot wrote on disk and rtk stayed active. Requiring an explicit off
# also keeps an unconfigured image (ENABLE_RTK unset — it is not set anywhere in
# Dockerfile.agent) from silently wiping a hand-installed rtk, and turns a typo
# such as "True" or "1" into a loud log line instead of a silent install or a
# silent wipe.
if command -v rtk >/dev/null 2>&1; then
    # Which agent variant this image ships. Order is the image variant priority
    # and is unchanged from the original block.
    RTK_LABEL="" RTK_INIT_ARGS=()
    if   [ -n "${MULTICA_CLAUDE_PATH}" ];      then RTK_LABEL="claude";      RTK_INIT_ARGS=( -g )
    elif [ -n "${MULTICA_CURSOR_PATH}" ];      then RTK_LABEL="cursor";      RTK_INIT_ARGS=( -g --agent cursor )
    elif [ -n "${MULTICA_CODEX_PATH}" ];       then RTK_LABEL="codex";       RTK_INIT_ARGS=( -g --codex )
    elif [ -n "${MULTICA_OPENCODE_PATH}" ];    then RTK_LABEL="opencode";    RTK_INIT_ARGS=( -g --opencode )
    # antigravity does not support -g (no global workspace config)
    elif [ -n "${MULTICA_ANTIGRAVITY_PATH}" ]; then RTK_LABEL="antigravity"; RTK_INIT_ARGS=( --agent antigravity )
    fi

    case "${ENABLE_RTK:-}" in
        true)
            if [ -n "${RTK_LABEL}" ]; then
                ( rtk init "${RTK_INIT_ARGS[@]}" ) || echo "[entrypoint] RTK init failed for ${RTK_LABEL}."
            else
                echo "[entrypoint] ENABLE_RTK=true but no MULTICA_*_PATH is set — cannot tell which variant to initialise; no-op."
            fi
            ;;
        false|0|no|off)
            # Deliberately not keyed on MULTICA_*_PATH. Keying the removal on the
            # same detection as the install is what makes a disable conditional
            # on a variable that a runtime may not carry, and an unset or stale
            # one silently reinstates the one-way bug. Each call below is
            # idempotent and exits 0 on a clean image, so the cost of a clean
            # boot is ~2ms per variant.
            for rtk_disable_args in "-g" "-g --agent cursor" "-g --codex" "-g --opencode"; do
                # shellcheck disable=SC2086 # deliberate word splitting into argv
                ( rtk init ${rtk_disable_args} --uninstall ) || echo "[entrypoint] RTK uninstall failed for '${rtk_disable_args}'."
            done
            # rtk has no uninstall for antigravity: `--uninstall` without -g exits
            # 1 with "Uninstall only works with --global flag", and -g only sweeps
            # ~/.claude, so neither touches the rules file the enable path wrote
            # into the entrypoint's CWD. That one has to go by hand.
            rm -f "${PWD}/.agents/rules/antigravity-rtk-rules.md"
            # Say what was attempted, not what was verified: rtk prints
            # "nothing to remove" while it is in fact deleting the opencode
            # plugin, so its own output is not evidence either way.
            echo "[entrypoint] RTK disable: ran --uninstall for claude, cursor, codex, opencode and removed the antigravity rules file if present."
            ;;
        "")
            echo "[entrypoint] ENABLE_RTK unset — rtk not configured, no-op."
            ;;
        *)
            echo "[entrypoint] ENABLE_RTK='${ENABLE_RTK}' is not a recognised value (use 'true' or 'false'); treating as unset, no-op."
            ;;
    esac
fi

exec "$@"
