{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.caddy;
in
{
  options.hosts.caddy = {
    enable = mkEnableOption "Caddy base";
  };

  config = mkIf cfg.enable {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [
          "github.com/corazawaf/coraza-caddy/v2@v2.1.0"
          "github.com/martijnboers/caddy-webdav@v0.0.0-20260104124919-990d6e445da5"
        ];
        hash = "sha256-84mPDyqbDszaL/Z1YbU8O+208qbjyp2tpURA0YciZQk=";
      };

      extraConfig = ''
        (headscale) {
          @internal remote_ip 100.64.0.0/10
          tls {
            ca https://acme.thuis:4443/acme/gitgetgot/directory
          }
        }
        (mtls) {
          tls {
            client_auth {
              mode require_and_verify
              trust_pool file {
                pem_file "${inputs.secrets}/keys/plebs4platinum.crt"
              }
            }
          }
        }
      '';

      globalConfig = ''
        metrics {
          per_host
        }
        servers {
          trusted_proxies static 100.64.0.0/10
          enable_full_duplex
        }

        order coraza_waf first
        order webdav before file_server
      '';
      virtualHosts = {
        "webdav.thuis:80".extraConfig = ''
          import headscale
          handle @internal {
            route {
              basic_auth {
                martijn $2a$14$ASOmj.jZv9cvR0W5E26UkOpCD7fjCWhfEKnI0YKUChqDsfx9FqR/O
              }
              rewrite /android /android/
              webdav /android/* {
                root /mnt/zwembad/app/android
                prefix /android
              }
              file_server
            }
          }
          respond 403
        '';
      };
    };

    systemd.services.caddy = {
      serviceConfig = {
        # Required to use ports < 1024
        AmbientCapabilities = "cap_net_bind_service";
        CapabilityBoundingSet = "cap_net_bind_service";
        TimeoutStartSec = "5m";
      };
    };
  };
}
