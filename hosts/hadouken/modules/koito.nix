{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.koito;
in
{
  options.hosts.koito = {
    enable = mkEnableOption "Koito music scrobbler";
  };

  config = mkIf cfg.enable {
    users.users.koito = {
      isSystemUser = true;
      group = "koito";
    };
    users.groups.koito = { };

    systemd.services.koito = {
      description = "Koito music scrobbler";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        KOITO_CONFIG_DIR = "/mnt/zwembad/app/koito";
        KOITO_LISTEN_PORT = "4110";
        KOITO_DEFAULT_USERNAME = "admin";
        KOITO_DEFAULT_THEME = "yuu";
      };
      serviceConfig = {
        Type = "simple";
        User = "koito";
        Group = "koito";
        ExecStart = "${lib.getExe pkgs.koito}";
        EnvironmentFile = config.age.secrets.koito.path;
        Restart = "on-failure";

        ProtectSystem = "full";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        ProtectClock = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
      };
    };

    services.caddy.virtualHosts."koito.thuis".extraConfig = ''
      import headscale
      handle @internal {
        reverse_proxy http://127.0.0.1:4110
      }
      respond 403
    '';

    age.secrets.koito = {
      file = "${inputs.secrets}/koito.age";
      owner = "koito";
      group = "koito";
    };
  };
}
