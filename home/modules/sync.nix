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
  rcloneBin = "${pkgs.rclone}/bin/rclone";
  rcloneConfig = config.age.secrets.sync-rclone-conf.path;
in
{
  options.maatwerk.sync = {
    enable = mkEnableOption "Bidirectional rclone bisync for Notes and pi sessions to Garage S3 (encrypted)";
    notesPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Notes";
      description = "Local path to notes directory";
    };
    sessionsPath = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.pi/agent/sessions";
      description = "Local path to pi sessions directory";
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
      services = {
        rclone-notes-sync = {
          Unit = {
            Description = "Bidirectional sync ~/Notes <-> Garage S3 (encrypted)";
            After = [ "network-online.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${rcloneBin} --config ${rcloneConfig} bisync ${cfg.notesPath} notes-crypt: --conflict-resolve newer --create-empty-src-dirs --resilient --max-lock 2m";
            IOSchedulingClass = "idle";
            Nice = 19;
          };
        };

        rclone-sessions-sync = {
          Unit = {
            Description = "Bidirectional sync ~/.pi/agent/sessions <-> Garage S3 (encrypted)";
            After = [ "network-online.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${rcloneBin} --config ${rcloneConfig} bisync ${cfg.sessionsPath} sessions-crypt: --conflict-resolve newer --create-empty-src-dirs --resilient --max-lock 2m";
            IOSchedulingClass = "idle";
            Nice = 19;
          };
        };
      };

      timers = {
        rclone-notes-sync = {
          Unit = {
            Description = "Sync notes every ${cfg.timerInterval}";
          };
          Timer = {
            OnUnitActiveSec = cfg.timerInterval;
            OnBootSec = "2m";
            Persistent = true;
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };

        rclone-sessions-sync = {
          Unit = {
            Description = "Sync pi sessions every ${cfg.timerInterval}";
          };
          Timer = {
            OnUnitActiveSec = cfg.timerInterval;
            OnBootSec = "2m";
            Persistent = true;
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      };
    };

    # Ensure parent directories exist for rclone bisync state files
    home.file.".cache/rclone/bisync/.keep".text = "";
  };
}
