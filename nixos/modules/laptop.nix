{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.hosts.laptop;
in
{
  options.hosts.laptop = {
    enable = mkEnableOption "Base laptop";
  };

  config = mkIf cfg.enable {
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 50;
      };
    };

    services.logind.settings.Login = {
      # https://www.freedesktop.org/software/systemd/man/logind.conf.html
      HandleLidSwitch = "ignore";
    };

    boot.kernelParams = [ "i2c_hid.polling_mode=1" ];

    systemd.sleep.settings.Sleep = {
      HibernateDelaySec = "30m";
      SuspendState = "mem";
    };

    # ── rclone sync before sleep — non-blocking, quick timeout ──
    # If network is unreachable, rclone bails in ~20s via --contimeout/--low-level-retries.
    # TimeoutStartSec=25s ensures sleep proceeds no matter what.
    systemd.services.rclone-sync-before-sleep = {
      description = "Final rclone bisync before sleep";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "martijn";
        Environment = "RCLONE_CONFIG=/run/agenix/sync-rclone-conf";
        TimeoutStartSec = 25;
        IOSchedulingClass = "idle";
        Nice = 19;
      };
      script = ''
        set -e

        # Restore stale listing files from prior crashes
        cache="$HOME/.cache/rclone/bisync"
        for f in "$cache"/*.lst-old; do
          [ -f "$f" ] || continue
          lst="''${f%-old}"
          [ -f "$lst" ] || cp "$f" "$lst"
        done

        mkBsync() {
          [ -d "$1" ] || return 0
          ${pkgs.rclone}/bin/rclone bisync "$1" "$2" \
            --conflict-resolve newer \
            --create-empty-src-dirs \
            --resilient \
            --max-lock 2m \
            --contimeout 10s \
            --low-level-retries 2 \
            --timeout 60s \
            --log-level ERROR \
            || true  # never block sleep on sync failure
        }

        mkBsync "$HOME/Notes" "notes-crypt:"
        mkBsync "$HOME/.pi/agent/sessions" "sessions-crypt:"
      '';
    };
  };
}
