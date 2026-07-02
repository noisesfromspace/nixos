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
  gpg-key = "${inputs.secrets}/keys/pgp.asc";
  wkd = pkgs.runCommand "wkd-output" { nativeBuildInputs = [ pkgs.gnupg ]; } ''
    mkdir -p $out/hu
    cat ${gpg-key} | gpg --dearmor > $out/hu/nnzg8pw4hsizdcd9u31yy1ony94u94tw
    touch $out/policy
  '';
in
{
  options.hosts.caddy = {
    enable = mkEnableOption "Ghetto CloudFlare proxies";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/darkweak/souin/plugins/caddy@v1.7.8" ];
        hash = "sha256-fvoL28WQfmtQezzm+LCa5uVkxvc5K18FMcqfSifjriI=";
      };
      globalConfig = ''
        metrics {
            per_host
        }
        servers {
            trusted_proxies static 100.64.0.0/10
            enable_full_duplex
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
      virtualHosts = {
        "boers.email" = {
          serverAliases = [ "plebian.nl" ];
          extraConfig = ''
            cache {
                ttl 1h
            }
            root * ${pkgs.info}/
            encode zstd gzip
            file_server

            @bots path /wp-login.php /wp-admin/* /xmlrpc.php 
            redir @bots http://speed.transip.nl/1tb.bin 302

            handle_path /.well-known/openpgpkey/* {
              root * ${wkd}
              header Content-Type application/octet-stream
              header Access-Control-Allow-Origin *
              file_server
            }

            header X-Robots-Tag "noindex"
            header /.well-known/matrix/* Content-Type application/json
            header /.well-known/matrix/* Access-Control-Allow-Origin *
            respond /.well-known/matrix/server `{"m.server": "matrix.boers.email:443"}`
            respond /.well-known/matrix/client `{
              "m.homeserver": {"base_url":"https://matrix.boers.email"},
              "m.identity_server":{"base_url":"https://identity.boers.email"}
            }`
          '';
        };
        "matrix.boers.email" = {
          extraConfig = ''
            header X-Robots-Tag "noindex"
            reverse_proxy /_matrix/* hadouken.machine.thuis:5553
            reverse_proxy /_synapse/client/* hadouken.machine.thuis:5553
          '';
        };
        "resume.boers.email" = {
          extraConfig = ''
            header X-Robots-Tag "noindex"
            cache { ttl 1h }
            root * ${pkgs.resume}
            encode zstd gzip
            file_server
          '';
        };
        "blog.boers.email" = {
          extraConfig = ''
            cache { ttl 1h }
            root * ${pkgs.blog}/
            encode zstd gzip
            file_server
          '';
        };
        "random.storage.boers.email" = {
          serverAliases = [ "mastodon.storage.boers.email" ];
          extraConfig = ''
            header X-Robots-Tag "noindex"

            reverse_proxy hadouken.machine.thuis:3902
          '';
        };
        "p.plebian.nl" = {
          extraConfig = ''
            header X-Robots-Tag "noindex"
            basic_auth {
              martijn $2a$14$5IMomLZ8smU2w4VSbVN/ae8PNqQz7PfcmKpAJmgTMY58Wgoj3uRam
            }
            reverse_proxy hadouken.machine.thuis:5555 {
                header_up X-Forwarded-Host p.plebian.nl
                header_up X-Forwarded-Proto https
                header_up X-Real-IP {remote_host}
            }
          '';
        };
        # "photos.boers.email" = {
        #   extraConfig = ''
        #     reverse_proxy https://immich.thuis {
        #         header_up X-Forwarded-Host photos.boers.email
        #         header_up X-Forwarded-Proto https
        #         header_up X-Real-IP {remote_host}
        #     }
        #   '';
        # };
        "noisesfrom.space" = {
          extraConfig = # bash
            ''
              # Encode responses with Gzip
              encode gzip

              # Set security-related headers
              header {
                  # Enable HSTS
                  Strict-Transport-Security "max-age=31536000;"
                  # Prevent clickjacking
                  X-Frame-Options "DENY"
                  # Prevent MIME-sniffing
                  X-Content-Type-Options "nosniff"
                  # Enable XSS protection
                  X-XSS-Protection "1; mode=block"
                  # Referrer Policy
                  Referrer-Policy "strict-origin-when-cross-origin"
              }

              header /emoji/* Cache-Control "public, max-age=31536000, immutable"
              header /packs/* Cache-Control "public, max-age=31536000, immutable"
              header /assets/* Cache-Control "public, max-age=31536000, immutable" 
              header /system/accounts/avatars/* Cache-Control "public, max-age=31536000, immutable"
              header /system/media_attachments/files/* Cache-Control "public, max-age=31536000, immutable"

              @static_assets {
                  path /assets/* /packs/* /emoji/* /sounds/*
                  path /favicon.ico /robots.txt /manifest.json /sw.js
                  path /apple-touch-icon*.png /mstile-*.png /browserconfig.xml
                  path /oops.html /500.html /404.html /422.html /403.html # Error pages
              }
              handle @static_assets {
                  root * ${pkgs.glitch-soc}/public
                  file_server
              }

              handle /api/v1/streaming/* {
                  reverse_proxy hadouken.machine.thuis:5552
              }

              handle {
                  reverse_proxy hadouken.machine.thuis:5551
              }
              handle_errors {
                  root * ${pkgs.glitch-soc}/public
                  rewrite * /500.html 
                  file_server
              }
            '';
        };
        # Dummy endpoint to get certificates for mail server
        "mx1.plebian.nl" = {
          serverAliases = [ "mx1.boers.email" ];
          extraConfig = ''
            respond "Mail server certificate endpoint" 200
          '';
        };
      };
    };

    systemd.services.caddy = {
      serviceConfig = {
        EnvironmentFile = config.age.secrets.caddy.path;
        AmbientCapabilities = "cap_net_bind_service";
        CapabilityBoundingSet = "cap_net_bind_service";
        TimeoutStartSec = "5m";
      };
    };

    age.secrets = {
      caddy.file = "${inputs.secrets}/caddy.age";
    };
  };
}
