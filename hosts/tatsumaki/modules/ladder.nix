{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.hosts.ladder;
  port = 18469;
in
{
  options.hosts.ladder = {
    enable = mkEnableOption "12ft.io replacement";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts."ladder.thuis".extraConfig = ''
      import headscale
      handle @internal {
        reverse_proxy http://127.0.0.1:${toString port}
      }
      respond 403
    '';

    systemd.services.ladder = {
      description = "Laddder";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.ladder} -p ${toString port}";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "5s";

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
