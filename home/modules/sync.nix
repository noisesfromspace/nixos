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
  bisyncCacheDir = "${config.home.homeDirectory}/.cache/rclone/bisync";

  restoreListings = pkgs.writeShellScript "rclone-restore-listings" ''
    set -e
    cache="$1"
    restored=0
    for f in "$cache"/*.lst-old; do
      [ -f "$f" ] || continue
      lst="''${f%-old}"
      if [ ! -f "$lst" ]; then
        cp "$f" "$lst"
        restored=1
      fi
    done
    if [ "$restored" -eq 1 ]; then
      echo "rclone-restore-listings: restored missing .lst files from -old backups"
    fi
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

  mkService =
    {
      name,
      path,
      remote,
      ...
    }:
    nameValuePair "rclone-${name}-sync" {
      Unit = {
        Description = "Bidirectional sync ${path} <-> ${remote}";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${restoreListings} ${bisyncCacheDir}";
        ExecStart = "${rcloneBin} --config ${rcloneConfig} bisync ${path} ${remote} --conflict-resolve newer --create-empty-src-dirs --resilient --max-lock 2m";
        IOSchedulingClass = "idle";
        Nice = 19;
      };
    };
  mkTimer =
    { name, ... }:
    nameValuePair "rclone-${name}-sync" {
      Unit.Description = "Sync ${name} every ${cfg.timerInterval}";
      Timer = {
        OnUnitActiveSec = cfg.timerInterval;
        OnBootSec = "2m";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
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
      default = "5m";
      description = "Systemd OnUnitActiveSec for sync timers";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.rclone ];

    age.secrets.sync-rclone-conf = {
      file = "${inputs.secrets}/sync-rclone-conf.age";
      mode = "600";
    };

    systemd.user = {
      services = listToAttrs (map mkService syncPairs);
      timers = listToAttrs (map mkTimer syncPairs);
    };

    home.file.".cache/rclone/bisync/.keep".text = "";
  };
}
