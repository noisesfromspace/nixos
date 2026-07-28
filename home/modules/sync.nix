{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.sync;
  rcloneBin = lib.getExe pkgs.rclone;
  rcloneConfig = config.age.secrets.sync-rclone-conf.path;

  syncPairs = builtins.filter (p: p.enable) [
    {
      name = "notes";
      path = cfg.notes.path;
      remote = "notes-crypt:";
      enable = cfg.notes.enable;
    }
    {
      name = "sessions";
      path = cfg.sessions.path;
      remote = "sessions-crypt:";
      enable = cfg.sessions.enable;
    }
    {
      name = "work";
      path = cfg.work.path;
      remote = "work-crypt:";
      enable = cfg.work.enable;
    }
  ];

  # Combined sync script — runs all enabled pairs, exits 0 even on failure
  # (so sleep/shutdown are never blocked). Used by timer, shutdown hook, and sleep hook.
  syncAll = pkgs.writeShellScriptBin "rclone-sync-all" ''
    set -e
    export RCLONE_CONFIG="${rcloneConfig}"

    cache="$HOME/.cache/rclone/bisync"
    for f in "$cache"/*.lst-old; do
      [ -f "$f" ] || continue
      lst="''${f%-old}"
      [ -f "$lst" ] || cp "$f" "$lst"
    done

    rc=0
  ${lib.concatMapStrings (
    p: ''
      if [ -d "${p.path}" ]; then
        ${rcloneBin} bisync "${p.path}" "${p.remote}" \
          --conflict-resolve newer \
          --create-empty-src-dirs \
          --resilient \
          --max-lock 2m \
          --contimeout 10s \
          --low-level-retries 2 \
          --timeout 60s \
          --log-level ERROR \
          || rc=1
      fi
    ''
  ) syncPairs}
    exit $rc
  '';

  mkSyncOpts =
    {
      defaultEnable ? false,
      defaultPath,
      description,
    }:
    {
      enable = mkOption {
        type = types.bool;
        default = defaultEnable;
        description = "Enable ${description} sync";
      };
      path = mkOption {
        type = types.str;
        default = defaultPath;
        description = "Local path to ${description} directory";
      };
    };
in
{
  options.maatwerk.sync = {
    enable = mkEnableOption "Bidirectional rclone bisync to remote (encrypted)";
    notes = mkSyncOpts {
      defaultEnable = true;
      defaultPath = "${config.home.homeDirectory}/Notes";
      description = "notes";
    };
    sessions = mkSyncOpts {
      defaultEnable = true;
      defaultPath = "${config.home.homeDirectory}/.pi/agent/sessions";
      description = "pi sessions";
    };
    work = mkSyncOpts {
      defaultPath = "/opt/work";
      description = "work";
    };
    timerInterval = mkOption {
      type = types.str;
      default = "20m";
      description = "Systemd OnUnitActiveSec for sync timers";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.sync-rclone-conf = {
      file = "${inputs.secrets}/sync-rclone-conf.age";
      mode = "600";
    };

    systemd.user = {
      # ── Periodic sync (every 20min, catches up after sleep via Persistent=true) ──
      services.rclone-sync = {
        Unit = {
          Description = "rclone bisync all enabled pairs";
          After = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe syncAll;
          IOSchedulingClass = "idle";
          Nice = 19;
        };
      };
      timers.rclone-sync = {
        Unit.Description = "Sync every ${cfg.timerInterval}";
        Timer = {
          OnUnitActiveSec = cfg.timerInterval;
          OnBootSec = "2m";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      # ── Shutdown hook — syncs before the user session ends ──
      # RemainAfterExit + ExecStop means: nothing on boot, sync on shutdown.
      # network-online.target is NOT required here — if network is down,
      # rclone bails in ~20s via --contimeout/--low-level-retries.
      services.rclone-sync-shutdown = {
        Unit = {
          Description = "Final rclone bisync before shutdown";
          Conflicts = "shutdown.target";
          Before = "shutdown.target";
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
          ExecStop = lib.getExe syncAll;
          TimeoutStopSec = 25;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };

    home.file.".cache/rclone/bisync/.keep".text = "";
  };
}
