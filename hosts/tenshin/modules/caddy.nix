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
      package = pkgs.caddy;
      logFormat = "level DEBUG";
      globalConfig = ''
        servers {
            trusted_proxies static 100.64.0.0/10
        }
      '';
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
    };
  };
}
