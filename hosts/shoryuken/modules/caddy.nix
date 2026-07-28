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
  blocked-ja4s = pkgs.writeText "blocked_ja4s.txt" ''
    # Blocked JA4 TLS fingerprints — one per line, # for comments
    # Sliver C2
    t13d190900_9dc949149365_97f8aa674fd9
    # Cobalt Strike (HTTPS beacon)
    # t13d1517h2_8daaf6152771_b0da82dd1658
    # Evilginx
    # t13d191000_9dc949149365_e7c285222651
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
        plugins = [
          "github.com/darkweak/souin/plugins/caddy@v1.7.8"
          "github.com/noisesfromspace/caddy-ja3ja4@v0.0.0-20260728150355-31c3a6057526"
          "github.com/mholt/caddy-ratelimit@v0.1.0"
        ];
        hash = "sha256-KVs7Op0PI5/4TPL2iI/DVRhICv1h+sPpwrOnOE+rnoY=";
      };
      globalConfig = ''
        auto_https disable_redirects
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
        (ratelimit) {
          rate_limit {
            zone default {
              key {remote_host}
              events 60
              window 1m
            }
          }
        }
        (ratelimit_loose) {
          rate_limit {
            zone api {
              key {remote_host}
              events 300
              window 1m
            }
          }
        }
      '';
      virtualHosts = {
        "boers.email" = {
          serverAliases = [ "plebian.nl" ];
          extraConfig = ''
            import ratelimit
            cache {
                ttl 1h
            }
            ja3_ja4 {
                block_file ${blocked-ja4s}
                watch_block_file
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
            import ratelimit
            header X-Robots-Tag "noindex"
            cache { ttl 1h }
            root * ${pkgs.resume}
            encode zstd gzip
            file_server
          '';
        };
        "blog.boers.email" = {
          extraConfig = ''
            import ratelimit
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
              import ratelimit_loose
              ja3_ja4 {
                  block_file ${blocked-ja4s}
                  watch_block_file
              }

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
        "ja4.boers.email" = {
          extraConfig = ''
            ja3_ja4 {
            }
            respond "{tls.ja4}" 200
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
