{
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.writeShellApplication {
  name = "worker-sandbox";
  runtimeInputs = with pkgs; [
    bubblewrap
    coreutils
    rsync
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
          state_dir=/home/worker/.pi/worker-sandbox

          "$SUDO" -u worker -- mkdir -p \
            "$state_dir/agent/sessions" \
            "$state_dir/npm/cache" \
            "$state_dir/cache" \
            "$state_dir/home"
        }

        seed_agent_config() {
          local agent_dir="$state_dir/agent"

          # Keep worker agent config synced with the latest shared base each launch.
          if [[ -d /opt/pi-agent-base ]]; then
            "$SUDO" -u worker -- "$RSYNC" -rltD --delete \
              --exclude 'sessions' \
              --exclude 'auth.json' \
              --exclude 'AGENTS.md' \
              /opt/pi-agent-base/ "$agent_dir"/
          fi

          # Always regenerate AGENTS so worker preamble and shared instructions stay current.
          "$SUDO" -u worker -- "$BASH" -lc "cat > '$agent_dir/AGENTS.md' <<'EOF'
    ## Worker-specific note

    - This is the isolated \`worker\` account for pi coding agent sessions.
    - You do not have sudo privileges.
    - If something needs sudo or root access, the user must do it themselves in a different terminal.
    - Keep changes scoped to the worker workspace and avoid system-wide edits.
    - If a required CLI tool is missing, prefer temporary usage via \`nix shell nixpkgs#<package>\`.

    ## Shared instructions
    EOF"

          if [[ -f /opt/pi-agent-base/AGENTS.md ]]; then
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

            --dir /opt/worker-state
            --bind "$state_dir" /opt/worker-state

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

            --setenv HOME /opt/worker-state/home
            --setenv USER worker
            --setenv LOGNAME worker
            --setenv SHELL /run/current-system/sw/bin/zsh
            --setenv __NIXOS_SET_ENVIRONMENT_DONE 1
            --setenv TERM xterm-256color
            --setenv PATH ${
              lib.makeBinPath [
                pkgs.pi-coding-agent
                pkgs.coreutils
                pkgs.pandoc # read from docs
                pkgs.ddgr # cli ddg
                pkgs.w3m # read from web
                pkgs.nodejs_22
                pkgs.python313
                pkgs.python313Packages.trafilatura # gather text from articles
              ]
            }:/run/current-system/sw/bin

            --setenv PI_CODING_AGENT_DIR /opt/worker-state/agent
            --setenv PI_CODING_AGENT_SESSION_DIR /opt/worker-state/agent/sessions
            --setenv PI_AUTH_JSON /run/agenix/pi-auth
            --setenv NPM_CONFIG_PREFIX /opt/worker-state/npm
            --setenv NPM_CONFIG_CACHE /opt/worker-state/npm/cache
            --setenv npm_config_prefix /opt/worker-state/npm
            --setenv npm_config_cache /opt/worker-state/npm/cache
            --setenv npm_config_update_notifier false
            --setenv XDG_CACHE_HOME /opt/worker-state/cache

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
