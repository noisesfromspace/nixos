{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.umami;
in
{
  options.hosts.umami = {
    enable = mkEnableOption "Self hosted analytics";
  };

  config = mkIf cfg.enable {

    users.users.umami = {
      isSystemUser = true;
      group = "umami";
    };
    users.groups.umami = { };

    age.secrets = {
      geoip.file = "${inputs.secrets}/geoip.age";
      umami = {
        file = "${inputs.secrets}/umami.age";
        owner = "umami";
        group = "umami";
      };
      umami-db = {
        file = "${inputs.secrets}/umami-db.age";
        owner = "umami";
        group = "umami";
      };
    };

    services.geoipupdate = {
      enable = true;
      settings = {
        EditionIDs = [ "GeoLite2-City" ];
        AccountID = 1232114;
        LicenseKey = config.age.secrets.geoip.path;
      };
    };

    services.caddy.virtualHosts = {
      "analytics.thuis" = {
        extraConfig = ''
          import headscale
          handle @internal {
            reverse_proxy 127.0.0.1:3000
          }
        '';
      };
      "views.boers.email" = {
        extraConfig = ''
          @public_api {
            path /script.js /api/send /api/config
          }

          handle @public_api {
            reverse_proxy 127.0.0.1:3000
          }

          handle {
            respond "Not Found" 404
          }
        '';
      };
    };

    services.umami = {
      enable = true;
      createPostgresqlDatabase = false;
      settings = {
        HOSTNAME = "127.0.0.1";
        PORT = 3000;
        APP_SECRET_FILE = config.age.secrets.umami.path;
        DATABASE_URL_FILE = config.age.secrets.umami-db.path;
        DISABLE_TELEMETRY = true;
        GEO_DATABASE_URL = "${toString config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-City.mmdb";
      };
    };

    systemd.services.umami = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "umami";
        Group = "umami";
        BindReadOnlyPaths = [ config.services.geoipupdate.settings.DatabaseDirectory ];
      };
    };

  };
}
