{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.mastodon;
in
{
  options.hosts.mastodon = {
    enable = mkEnableOption "Mastodon feddy";
  };

  config = mkIf cfg.enable {
    systemd.services = {
      socat-mastodon-web =
        let
          socketPath = "/run/mastodon-web/web.socket";
        in
        {
          enable = true;
          description = "Socat for mastodon-web";
          after = [
            "network-online.target"
            "mastodon-web.service"
          ];
          wants = [
            "network-online.target"
            "mastodon-web.service"
          ];
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 10;
          startLimitIntervalSec = 600;
          serviceConfig = {
            Restart = "on-failure";
            ProtectSystem = "strict";
            RuntimeDirectory = [ socketPath ];
            ExecStart = "${lib.getExe pkgs.socat} TCP-LISTEN:5551,fork,reuseaddr,bind=${config.global.tailscale_hosts.hadouken} UNIX-CONNECT:${socketPath}";
            RestartSec = 10;
          };
        };
      socat-mastodon-streaming =
        let
          socketPath = "/run/mastodon-streaming/streaming-1.socket";
        in
        {
          enable = true;
          description = "Socat for mastodon-streaming";
          after = [
            "network-online.target"
            "mastodon-web.service"
          ];
          wants = [
            "network-online.target"
            "mastodon-web.service"
          ];
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 10;
          startLimitIntervalSec = 600;
          serviceConfig = {
            Restart = "on-failure";
            ProtectSystem = "strict";
            RuntimeDirectory = [ socketPath ];
            ExecStart = "${lib.getExe pkgs.socat} TCP-LISTEN:5552,fork,reuseaddr,bind=${config.global.tailscale_hosts.hadouken} UNIX-CONNECT:${socketPath}";
            RestartSec = 10;
          };
        };
    };

    services.postgresqlBackup.databases = [ "mastodon" ];

    services.mastodon = {
      enable = true;
      package = pkgs.glitch-soc;
      streamingProcesses = 1;
      trustedProxy = "100.64.0.0/10,127.0.0.1";
      localDomain = "noisesfrom.space";
      configureNginx = false;
      smtp = {
        createLocally = false;
        fromAddress = "noreply@boers.email"; # required
      };
      extraEnvFiles = [ config.age.secrets.mastodon.path ];
      extraConfig = {
        SINGLE_USER_MODE = "true";
        MAX_TOOT_CHARS = "1000"; # yeey for glitch-soc

        S3_ENABLED = "true";
        S3_BUCKET = "mastodon";
        S3_REGION = "thuis";
        S3_ENDPOINT = "https://garage.thuis";
        S3_HOSTNAME = "mastodon.storage.boers.email";
        S3_ALIAS_HOST = "mastodon.storage.boers.email";
      };
      mediaAutoRemove = {
        enable = true;
        olderThanDays = 14;
      };
    };

    age.secrets = {
      mastodon.file = "${inputs.secrets}/mastodon.age";
    };
  };
}
