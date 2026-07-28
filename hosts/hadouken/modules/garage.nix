{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.garage;
in
{
  options.hosts.garage = {
    enable = mkEnableOption "Garage Object Storage";
  };

  config = mkIf cfg.enable {
    services.caddy.virtualHosts = {
      "garage.thuis".extraConfig = ''
        import headscale
        handle @internal {
          handle {
            reverse_proxy http://localhost:3900
          }
        }
        respond 403
      '';
      "garage-admin.thuis".extraConfig = ''
        import headscale
        import mtls

        handle @internal {
          reverse_proxy http://localhost:3909
        }
        respond 403
      '';
    };

    services.garage = {
      enable = true;
      package = pkgs.garage_2;
      settings = {
        metadata_dir = "/var/lib/garage/meta";
        data_dir = "/mnt/zwembad/games/garage";
        db_engine = "sqlite";

        replication_factor = 1;

        rpc_bind_addr = "[::]:3901";
        rpc_public_addr = "127.0.0.1:3901";

        s3_api = {
          s3_region = "thuis";
          api_bind_addr = "[::]:3900";
        };

        s3_web = {
          bind_addr = "[::]:3902";
          root_domain = ".storage.boers.email";
          index = "index.html";
        };

        admin = {
          api_bind_addr = "[::]:3903";
        };
      };
      environmentFile = config.age.secrets.garage.path;
    };

    users.users.garage = {
      isSystemUser = true;
      group = "garage";
      home = "/var/lib/garage";
      createHome = true;
    };
    users.groups.garage = { };

    systemd.services.garage.serviceConfig = {
      User = "garage";
      Group = "garage";
      DynamicUser = lib.mkForce false;
    };

    # TODO: https://git.deuxfleurs.fr/Deuxfleurs/garage-webadmin
    # systemd.services.garage-webui = {
    #   enable = true;
    #   description = "Garage Web UI";
    #   after = [ "garage.service" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "simple";
    #     User = "garage";
    #     Group = "garage";
    #     ExecStart = "${pkgs.garage-webui}/bin/garage-webui";
    #     Restart = "on-failure";
    #     Environment = [ "CONFIG_PATH=/etc/garage.toml" ];
    #     EnvironmentFile = config.age.secrets.garage.path;
    #   };
    # };

    age.secrets.garage = {
      file = "${inputs.secrets}/garage.age";
      owner = "garage";
      group = "garage";
    };
  };
}
