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
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/mholt/caddy-ratelimit@v0.1.0" ];
        hash = "sha256-eET4cfn1OGyl8rtq8/dO95eM+hvjLPi9IyyWz6vT5QQ=";
      };
      globalConfig = ''
        servers {
            trusted_proxies static 100.64.0.0/10
        }
      '';
      virtualHosts = {
        "ip.boers.email" = {
          extraConfig = ''
            header Content-Type "text/plain; charset=utf-8"
            templates
            respond "{{.RemoteIP}}"
          '';
        };
        # Dummy endpoint to get certificates for mail server
        "mx2.plebian.nl" = {
          serverAliases = [ "mx2.boers.email" ];
          extraConfig = ''
            respond "Mail server certificate endpoint" 200
          '';
        };
      };
      extraConfig = ''
        (ratelimit_headscale) {
          rate_limit {
            zone headscale_auth {
              match {
                path /oidc/* /machine/register
              }
              key {remote_host}
              events 20
              window 1m
            }
          }
        }
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
