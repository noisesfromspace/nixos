{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.headscale;
  hadoukenRecords = [
    "atuin"
    "bincache"
    "cal"
    "cal-http"
    "detection"
    "garage"
    "garage-admin"
    "immich"
    "kasm"
    "jelly"
    "media"
    "ollama"
    "monitoring"
    "paper"
    "pgadmin"
    "prowlarr"
    "radarr"
    "sonarr"
    "syncthing"
    "webdav"
  ];
  shoryukenRecords = [
    "ci"
    "admin-1-mail"
    "analytics"
  ];
  rekkakenRecords = [
    "notifications"
    "ladder"
    "vpn"
    "uptime"
    "admin-2-mail"
  ];
  tenshinRecords = [
    "chef"
    "tools"
  ];
  tatsumakiRecords = [
    "dns"
    "mempool"
  ];
  dosukoiRecords = [
    "acme"
    "auth"
    "leases"
    "vaultwarden"
  ];
  suzakuRecords = [
    "hass"
  ];
in
{
  options.hosts.headscale = {
    enable = mkEnableOption "VPN server";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ config.services.headscale.package ];

    services = {
      caddy.virtualHosts = {
        "headscale.boers.email" = {
          extraConfig = ''
            header X-Robots-Tag "noindex"
            reverse_proxy http://localhost:${toString config.services.headscale.port}
          '';
        };
        "derp-map.boers.email" = {
          extraConfig = ''
            header /regions Content-Type application/json
            respond /regions `${
              builtins.toJSON {
                Regions = {
                  "900" = {
                    RegionID = 900;
                    RegionCode = "lel";
                    RegionName = "The Void";
                    Nodes = [
                      {
                        Name = "1";
                        RegionID = 900;
                        HostName = "derp1.boers.email";
                      }
                      {
                        Name = "2";
                        RegionID = 900;
                        HostName = "derp2.boers.email";
                      }
                    ];
                  };
                };
              }
            }`
          '';
        };
      };

      borgbackup.jobs.default.paths = [ config.services.headscale.settings.database.sqlite.path ];

      headscale = {
        enable = true;
        address = "0.0.0.0";
        port = 7092;
        settings = {
          server_url = "https://headscale.boers.email";
          derp.urls = [
            "https://derp-map.boers.email/regions"
            "https://controlplane.tailscale.com/derpmap/default"
          ];
          oidc = {
            issuer = "https://auth.boers.email";
            client_id = "d88ca9d8-ee44-48d0-a993-b83a0830e937";
            client_secret_path = config.age.secrets.headscale.path;
            allowed_users = [
              "headscale-server@boers.email"
              "headscale-user@boers.email"
            ];
            expiry = 0; # disable
          };
          policy.path = pkgs.writeText "acl.json" (
            builtins.toJSON {
              hosts = {
                shoryuken = config.global.tailscale_hosts.shoryuken;
                tenshin = config.global.tailscale_hosts.tenshin;
                hadouken = config.global.tailscale_hosts.hadouken;
                tatsumaki = config.global.tailscale_hosts.tatsumaki;
                nurma = config.global.tailscale_hosts.nurma;
                donk = config.global.tailscale_hosts.donk;
                pixel = config.global.tailscale_hosts.pixel;
                dosukoi = config.global.tailscale_hosts.dosukoi;
                pikvm = config.global.tailscale_hosts.pikvm;
                rekkaken = config.global.tailscale_hosts.rekkaken;
              };

              acls = [
                {
                  action = "accept";
                  src = [ "*" ];
                  dst = [
                    "hadouken:80,443" # everyone access to hadouken web-services
                    "tatsumaki:80,443,53" # everyone access to dns (over TLS)
                    "rekkaken:80,443,8025" # send/receive notifications + internal email
                    "tenshin:123,4460" # timeserver
                  ];
                }
                {
                  action = "accept";
                  src = [ "dosukoi" ];
                  dst = [
                    "headscale-server@:80,443,4443" # http acme challange
                  ];
                }
                {
                  action = "accept";
                  src = [
                    "shoryuken"
                    "rekkaken"
                  ];
                  dst = [
                    "hadouken:5551,5552,5553,5555,3902" # reverse proxy ports
                    "hadouken:${toString config.services.immich.port}"
                    "hadouken:5432" # postgresql for stalwart
                  ];
                }
                {
                  action = "accept";
                  src = [
                    "shoryuken"
                    "rekkaken"
                  ];
                  dst = [
                    "shoryuken:17447" # stalwart zenoh p2p
                    "rekkaken:17447" # stalwart zenoh p2p
                  ];
                }
                {
                  action = "accept";
                  src = [ "headscale-user@" ];
                  dst = [
                    "hadouken:2049" # nfs
                    "headscale-server@:80,443"
                    "pixel:1080" # socks 5g
                    "tatsumaki:50001" # bitcoin node
                    "headscale-user@:53317" # localsend
                  ];
                }
                {
                  action = "accept";
                  src = [ "headscale-server@" ];
                  dst = [
                    "dosukoi:4443" # request acme certs
                  ];
                }
                {
                  action = "accept";
                  src = [ "hadouken" ];
                  dst = [
                    "headscale-server@:9002" # node exporter
                    "headscale-server@:2019" # caddy exporter
                    "headscale-server@:${toString config.services.endlessh-go.prometheus.port}"
                  ];
                }
                {
                  action = "accept";
                  src = [
                    "nurma"
                    "donk"
                  ];
                  dst = [
                    "headscale-server@:22"
                    "hadouken:5432" # postgresql
                    "pikvm:80,443"
                  ];
                }
              ];
            }
          );
          logtail.enabled = false;
          database = {
            type = "sqlite3";
            sqlite = {
              path = "/var/lib/headscale/db.sqlite";
            };
          };
          dns =
            let
              makeRecord = name: ip: {
                name = "${name}.thuis";
                type = "A";
                value = ip;
              };
            in
            {
              magic_dns = true;
              base_domain = "machine.thuis";
              nameservers.global = [
                config.global.tailscale_hosts.tatsumaki
                "9.9.9.9" # quad
              ];
              extra_records =
                (map (name: makeRecord name config.global.tailscale_hosts.hadouken) hadoukenRecords)
                ++ (map (name: makeRecord name config.global.tailscale_hosts.shoryuken) shoryukenRecords)
                ++ (map (name: makeRecord name config.global.tailscale_hosts.tatsumaki) tatsumakiRecords)
                ++ (map (name: makeRecord name config.global.tailscale_hosts.rekkaken) rekkakenRecords)
                ++ (map (name: makeRecord name config.global.tailscale_hosts.dosukoi) dosukoiRecords)
                ++ (map (name: makeRecord name config.global.tailscale_hosts.suzaku) suzakuRecords)
                ++ (map (name: makeRecord name config.global.tailscale_hosts.tenshin) tenshinRecords);
            };
          prefixes = {
            v4 = "100.64.0.0/10";
            v6 = "fd7a:115c:a1e0::/48";
          };
        };
      };
    };

    age.secrets = {
      headscale = {
        file = "${inputs.secrets}/headscale.age";
        owner = config.services.headscale.user;
      };
    };
  };
}
