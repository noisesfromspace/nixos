{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.writeShellApplication {
  name = "worker-sandbox";
  runtimeInputs = [
    pkgs.bubblewrap
    pkgs.coreutils
    pkgs.rsync
  ];

  text = ''
        set -euo pipefail

        SUDO=/run/wrappers/bin/sudo
        BWRAP=${lib.getExe pkgs.bubblewrap}
        RSYNC=${lib.getExe pkgs.rsync}
        BASH=${lib.getExe pkgs.bash}

        fail() {
          echo "worker-sandbox: $*" >&2
          exit 1
        }

        parse_args() {
          # Default: network enabled for agent usability.
          net=1
          case "''${1:-}" in
            --net|--network)
              net=1
              shift
              ;;
            --no-net|--offline)
              net=0
              shift
              ;;
          esac

          if [[ $# -gt 0 ]]; then
            fail "unexpected arguments: $*"
          fi
        }

        ensure_workdir() {
          [[ -n "''${PWD:-}" ]] || fail "PWD is not set"

          workdir="$(cd "$PWD" && pwd -P)"
          if [[ "$workdir" == /home/martijn || "$workdir" == /home/martijn/* ]]; then
            fail "refuse to run from /home/martijn; cd to a project dir first"
          fi
        }

        ensure_state_dirs() {
          # If older runs left this tree non-writable for worker, reset it.
          if [[ -d "$workdir/.pi/agent" ]] && ! "$SUDO" -u worker -- test -w "$workdir/.pi/agent"; then
            rm -rf "$workdir/.pi"
          fi

          "$SUDO" -u worker -- mkdir -p \
            "$workdir/.pi/agent/sessions" \
            "$workdir/.npm"
        }

        seed_agent_config() {
          local agent_dir="$workdir/.pi/agent"

          if [[ -e "$agent_dir/.worker-seeded" ]] && [[ -f "$agent_dir/AGENTS.md" ]] && [[ -f "$agent_dir/settings.json" ]]; then
            return 0
          fi

          if [[ -d /opt/pi-agent-base ]]; then
            "$SUDO" -u worker -- "$RSYNC" -rltD --delete \
              --exclude 'sessions' \
              --exclude 'auth.json' \
              --exclude 'AGENTS.md' \
              /opt/pi-agent-base/ "$agent_dir"/

            # Recreate worker overload header + shared instructions.
            "$SUDO" -u worker -- "$BASH" -lc "cat > '$agent_dir/AGENTS.md' <<'EOF'
    ## Worker-specific note

    - This is the isolated \`worker\` account for pi coding agent sessions.
    - You do not have sudo privileges.
    - If something needs sudo or root access, the user must do it themselves in a different terminal.
    - Keep changes scoped to the worker workspace and avoid system-wide edits.

    ## Shared instructions
    EOF"

            "$SUDO" -u worker -- "$BASH" -lc "cat /opt/pi-agent-base/AGENTS.md >> '$agent_dir/AGENTS.md'"
          fi

          "$SUDO" -u worker -- touch "$agent_dir/.worker-seeded"
          "$SUDO" -u worker -- ln -sfn /run/agenix/pi-auth "$agent_dir/auth.json"
        }

        build_bwrap_args() {
          bwrap_args=(
            --die-with-parent
            --new-session
            --unshare-user
            --unshare-pid
            --unshare-ipc
            --unshare-uts
            --clearenv

            # Empty root, then allowlist only what we need.
            --tmpfs /
            --proc /proc
            --dev /dev

            --dir /opt
            --dir /opt/workspace
            --bind "$workdir" /opt/workspace
            --chdir /opt/workspace

            --dir /tmp

            --dir /nix
            --dir /nix/store
            --ro-bind /nix/store /nix/store

            --dir /run
            --dir /run/current-system
            --ro-bind /run/current-system /run/current-system
            --dir /run/agenix
            --ro-bind /run/agenix/pi-auth /run/agenix/pi-auth
            --ro-bind-try /run/agenix/llm /run/agenix/llm

            --dir /etc
            --ro-bind /etc/passwd /etc/passwd
            --ro-bind /etc/group /etc/group
            --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf
            --ro-bind-try /etc/hosts /etc/hosts
            --ro-bind-try /etc/resolv.conf /etc/resolv.conf
            --ro-bind-try /etc/localtime /etc/localtime
            --ro-bind-try /etc/machine-id /etc/machine-id
            --dir /etc/ssl
            --dir /etc/ssl/certs
            --ro-bind /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

            --setenv HOME /opt/workspace
            --setenv USER worker
            --setenv LOGNAME worker
            --setenv SHELL /run/current-system/sw/bin/zsh
            --setenv __NIXOS_SET_ENVIRONMENT_DONE 1
            --setenv TERM xterm-256color
            --setenv PATH ${
              lib.makeBinPath [
                pkgs.nodejs_22
                pkgs.coreutils
              ]
            }:/run/current-system/sw/bin

            --setenv PI_CODING_AGENT_DIR /opt/workspace/.pi/agent
            --setenv PI_CODING_AGENT_SESSION_DIR /opt/workspace/.pi/agent/sessions
            --setenv PI_AUTH_JSON /run/agenix/pi-auth
            --setenv NPM_CONFIG_PREFIX /opt/workspace/.npm

            --setenv SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt
            --setenv REQUESTS_CA_BUNDLE /etc/ssl/certs/ca-certificates.crt
            --setenv NODE_EXTRA_CA_CERTS /etc/ssl/certs/ca-certificates.crt
          )

          if [[ "$net" == 0 ]]; then
            bwrap_args+=(--unshare-net)
          fi
        }

        run_shell() {
          # SC2016-safe: use double quotes and escape runtime vars.
          local bootstrap
          bootstrap="if [[ -r /run/agenix/llm ]]; then
      while IFS= read -r line; do
        case \"\$line\" in
          \"\"|\\#*) continue ;;
          *=*) export \"\$line\" ;;
        esac
      done < /run/agenix/llm
    fi
    exec /run/current-system/sw/bin/zsh -f"

          exec "$SUDO" -u worker -- "$BWRAP" "''${bwrap_args[@]}" \
            "$BASH" -lc "$bootstrap"
        }

        parse_args "$@"
        ensure_workdir
        ensure_state_dirs
        seed_agent_config
        build_bwrap_args
        run_shell
  '';
}
