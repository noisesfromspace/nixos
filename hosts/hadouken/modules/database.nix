{
  config,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.database;
in
{
  options.hosts.database = {
    enable = mkEnableOption "PostgreSQL";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts = {
      "pgadmin.thuis".extraConfig = ''
        import headscale
        import mtls

        handle @internal {
          reverse_proxy http://localhost:${toString config.services.pgadmin.port}
        }
        respond 403
      '';
    };

    services.postgresql = {
      enable = true;
      enableTCPIP = true;
      ensureDatabases = [
        "umami"
      ];
      ensureUsers = [
        {
          name = "umami";
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
      authentication = lib.mkOverride 10 ''
        #type database  DBuser  range		        auth-method
        local all       all                     trust
        host  all       all     127.0.0.1/32    trust
        host  all       all     100.64.0.0/10   trust
      '';
    };

    age.secrets = {
      pgadmin.file = "${inputs.secrets}/pgadmin.age";
    };

    services.pgadmin = {
      enable = true;
      initialEmail = "m@b.com";
      initialPasswordFile = config.age.secrets.pgadmin.path;
    };

    services.postgresqlBackup = {
      enable = true;
      databases = [
        "stalwart"
        "umami"
      ];
    };

    services.borgbackup.jobs.default.paths = [
      config.services.postgresqlBackup.location
      config.services.garage.settings.metadata_dir
    ];
  };
}
